import os
from pathlib import Path
from collections import defaultdict
from app.app_manager import AppManager
from catalog.catalog import CatalogRestoreManager
from charts.backup_fetch import BackupChartFetcher
from charts.chart_version import ChartVersionUtils, ChartVersionRestore
from charts.backup_create import ChartCreationManager
from database.restore import RestoreCNPGDatabase
from kube.config_parse import KubeConfigReader
from kube.utils import KubeUtils
from kube.config_restore import KubeRestoreConfig
from kube.resources_restore import KubeRestoreResources
from zfs.snapshot import ZFSSnapshotManager
from zfs.lifecycle import ZFSLifecycleManager
from utils.logger import setup_global_logger
from utils.utils import waitForKubernetes
from utils.singletons import MiddlewareClientManager
from utils.type_check import type_check

class RestoreAll:
    def __init__(self, backup_dir: Path):
        """
        Initialize the RestoreAll class.

        Parameters:
        - backup_dir (Path): Directory where the backup is stored.
        """
        try:
            self.backup_dir = backup_dir.resolve()
            self.snapshot_name = str(self.backup_dir.name)
            self.backup_dataset = str(self.backup_dir.relative_to("/mnt"))
            self.backup_chart_dir = self.backup_dir / "charts"
            self.catalog_dir = self.backup_dir / "catalog"

            print("Rolling back snapshot for backup dataset, ensuring integrity...")
            self.snapshot_manager = ZFSSnapshotManager()
            self.snapshot_manager.rollback_all_snapshots(self.snapshot_name, self.backup_dataset)

            self.logger = setup_global_logger(self.backup_dir)
            self.logger.info("Restore process initialized.")

            self.middleware = MiddlewareClientManager.fetch()
            self.kubernetes_config_file = self.backup_dir / "kubernetes_config" / "kubernetes_config.json"
            self.kube_config_reader = KubeConfigReader(self.kubernetes_config_file)
            self.chart_version_utils = ChartVersionUtils(self.kube_config_reader.pool)
            self.app_manager = AppManager()
            self.zfs_manager = ZFSLifecycleManager()
            self.version_restore = ChartVersionRestore(self.kube_config_reader.pool)
            self.create_chart_manager = ChartCreationManager()
            self.restore_resources = KubeRestoreResources()
            self.chart_info = BackupChartFetcher(self.backup_chart_dir)

            self.failures = defaultdict(list)
            self.critical_failures = []
            self.create_list = []
            self.apps_dataset_exists = self.zfs_manager.dataset_exists(self.kube_config_reader.dataset)

            self.logger.info("Restore process setup complete.")
        except Exception as e:
            self.logger.error(f"Initialization error: {e}", exc_info=True)
            raise RuntimeError("Failed to initialize RestoreAll class") from e

    def _log_failures(self):
        """Log a summary of all restore failures."""
        self.logger.info("\nRestore Summary\n"
                           "---------------")
        if not self.failures and not self.critical_failures:
            self.logger.info("All applications restored successfully.")
            return

        if self.critical_failures:
            self.logger.error("Some applications encountered critical errors and could not proceed:")
            for app_name in self.critical_failures:
                self.logger.error(f"  {app_name}")

        if self.failures:
            self.logger.error("Some applications failed to restore:")
            for app_name, errors in self.failures.items():
                self.logger.error(f"{app_name}:")
                for error in errors:
                    self.logger.error(f"  {error}")

    @type_check
    def _handle_critical_failure(self, app_name: str, error: str):
        """Handle a critical failure that prevents further restoration."""
        self.logger.error(f"Critical error for {app_name}: {error}")
        self.failures[app_name].append(error)
        if app_name not in self.critical_failures:
            self.critical_failures.append(app_name)
            self.chart_info.handle_critical_failure(app_name)

    def restore_all(self):
        """Perform the entire restore process."""
        self.logger.info("Building Restore Plan\n"
                        "----------------------")
        try:
            self._build_restore_plan()
        except RuntimeError as e:
            self.logger.error(str(e))
            return

        if not self.chart_info.all_releases:
            self.logger.error("No releases found in backup directory.")
            return

        self.logger.info("Performing Initial Kubernetes Operations\n"
                         "----------------------------------------")
        try:
            self._initial_kubernetes_setup()
        except Exception as e:
            self._handle_critical_failure("Initial Kubernetes Setup", str(e))
            self._log_failures()
            return

        self.logger.info("\nRolling Back Volume Snapshots\n"
                           "-----------------------------")
        for app_name in self.chart_info.all_releases:
            try:
                self._rollback_volumes(app_name)
            except Exception as e:
                self.logger.error(f"Failed to rollback snapshots for {app_name}: {e}\n")
                self.failures[app_name].append(f"Failed to rollback volume snapshots: {e}")

        self.logger.info("\nStarting Kubernetes Services\n"
                         "----------------------------")
        try:
            self._start_kubernetes_services()
        except Exception as e:
            self._handle_critical_failure("Kubernetes Initialization", str(e))
            self._log_failures()
            return

        self.logger.info("\nRestoring Catalogs\n"
                           "------------------")
        try:
            CatalogRestoreManager(self.catalog_dir).restore()
        except Exception as e:
            self.logger.warning(f"Failed to restore catalog: {e}")
            self.failures["Catalog"].append(f"Restoration failed: {e}")

        if self.chart_info.apps_with_crds:
            self.logger.info("\nRestoring Custom Resource Definitions\n"
                               "-------------------------------------")
            for app_name in self.chart_info.apps_with_crds:
                self._restore_crds(app_name)

        self.logger.info("\nRestoring Applications\n"
                           "----------------------")

        cnpg_active = False
        self.job_handles = []

        for app_name in self.chart_info.all_releases:
            self.logger.info(f"Restoring {app_name}...")

            if app_name in self.chart_info.cnpg_apps:
                if "cloudnative-pg" in self.critical_failures:
                    self._handle_critical_failure(app_name, "Cloud Native PostgreSQL failed to restore")
                    continue

                if not cnpg_active and "cloudnative-pg" in self.chart_info.chart_names:
                    self.logger.info("Waiting for Cloud Native PostgreSQL to be active...")
                    self.app_manager.wait_for_app_active(self.chart_info.get_release_name("cloudnative-pg"))
                    cnpg_active = True
            try:
                if not self._restore_application(app_name):
                    self._handle_critical_failure(app_name, "Restoration failed")
                    self.logger.error(f"Critical failure in restoring {app_name}, skipping further processing.\n")
                    continue
            except Exception as e:
                self.logger.error(f"Failed to restore {app_name}: {e}\n")
                self.failures[app_name].append(f"Restoration failed: {e}")
                continue

            self.logger.info("")

        if self.job_handles:
            self.logger.info("Waiting For All Applications to Redeploy\n"
                            "----------------------------------------")
        for handle, app_name in self.job_handles:
            try:
                self.logger.info(f"Waiting for {app_name}...")
                self.middleware.wait(handle, job=True)
            except Exception as e:
                self.logger.error(f"Job for {app_name} failed: {e}")
                self._handle_critical_failure(app_name, str(f"Job failed: {e}"))

        if self.chart_info.apps_with_crds:
            self.logger.info("\nRestoring CNPG Databases\n"
                            "------------------------")
        for app_name in self.chart_info.cnpg_apps:
            try:
                self.logger.info(f"Restoring database for {app_name}...")
                db_manager = RestoreCNPGDatabase(app_name, self.chart_info.get_chart_name(app_name), self.chart_info.get_file(app_name, "database"))
                result = db_manager.restore()
                if not result["success"]:
                    self.failures[app_name].append(result["message"])
                else:
                    self.logger.info(result["message"])
            except Exception as e:
                self.logger.error(f"Failed to restore database for {app_name}: {e}")
                self.failures[app_name].append(f"Database restore failed: {e}")

        self._log_failures()

    def _restore_crds(self, app_name):
        self.logger.info(f"Restoring CRDs for {app_name}...")
        crd_failures = self.restore_resources.restore_crd(self.chart_info.get_file(app_name, "crds"))
        if crd_failures:
            self.failures[app_name].extend(crd_failures)

    def _initial_kubernetes_setup(self):
        """Initial Kubernetes setup before restoring applications."""
        if self.apps_dataset_exists:
            try:
                self.logger.info("Stopping Kubernetes services...")
                KubeUtils().stop_kubernetes_services()
            except Exception as e:
                self.logger.error(f"Failed to stop Kubernetes services: {e}")
                raise Exception("Initial Kubernetes setup failed.")

            try:
                self.logger.info("Deleting Rancher data...")
                KubeUtils().delete_rancher_data()
            except Exception as e:
                self.logger.error(f"Failed to delete Rancher data: {e}")
                raise Exception("Initial Kubernetes setup failed.")

            try:
                self.logger.info("Resetting Kubernetes CNI config...")
                KubeUtils().reset_kubernetes_cni_config()
            except Exception as e:
                self.logger.error(f"Failed to reset Kubernetes CNI config: {e}")
                raise Exception("Initial Kubernetes setup failed.")

        try:
            self.logger.info("Aborting sync jobs...")
            KubeUtils().abort_sync_jobs()
        except Exception as e:
            self.logger.error(f"Failed to abort sync jobs: {e}")
            raise Exception("Initial Kubernetes setup failed.")

        try:
            self.logger.info(f"Rolling back snapshots under {self.kube_config_reader.dataset}")
            self.snapshot_manager.rollback_all_snapshots(self.snapshot_name, self.kube_config_reader.dataset)
        except Exception as e:
            self.logger.error(f"Failed to rollback snapshots: {e}")
            raise Exception("Initial Kubernetes setup failed.")

        if self.apps_dataset_exists:
            try:
                k3s_dir = Path(f"/mnt/{self.kube_config_reader.dataset}/k3s")
                self.logger.info("Cleaning up k3s directory...")
                KubeUtils().cleanup_directory(k3s_dir)
            except Exception as e:
                self.logger.error(f"Failed to clean up k3s directory: {e}")
                raise Exception("Initial Kubernetes setup failed.")

            try:
                self.logger.info("Deleting and recreating datasets...")
                KubeUtils().delete_and_recreate_datasets(self.kube_config_reader.dataset)
            except Exception as e:
                self.logger.error(f"Failed to delete and recreate datasets: {e}")
                raise Exception("Initial Kubernetes setup failed.")

    @type_check
    def _rollback_volumes(self, app_name: str):
        """Rollback persistent volumes."""
        pv_files = self.chart_info.get_file(app_name, "pv_zfs_volumes")
        pv_only_files = [file for file in pv_files if file.name.endswith('-pv.yaml')]
        if pv_only_files:
            self.logger.info(f"Rolling back ZFS snapshots for {app_name}...")
            for pv_file in pv_only_files:
                result = self.snapshot_manager.rollback_persistent_volume(self.snapshot_name, pv_file)
                if not result["success"]:
                    self.failures[app_name].append(result["message"])
                    self.logger.error(f"Failed to rollback {pv_file} for {app_name}: {result['message']}")
                else:
                    self.logger.debug(result["message"])

    def _start_kubernetes_services(self):
        """Start Kubernetes services after initial setup."""
        self.logger.info("Restoring Kubernetes configuration...")

        KubeRestoreConfig(self.kubernetes_config_file).restore()        

        if self.apps_dataset_exists:
            self.logger.info("Starting Kubernetes services...")
            KubeUtils().start_kubernetes_services()

        if not waitForKubernetes():
            raise Exception("Kubernetes failed to initialize.")

    @type_check
    def _restore_application(self, app_name: str) -> bool:
        """Restore a single application."""
        try:
            if app_name not in self.create_list:
                self.logger.info(f"Creating {app_name} dataset if needed...")
                app_dataset = os.path.join(self.kube_config_reader.dataset, "releases", app_name, "charts")
                if not self.zfs_manager.dataset_exists(app_dataset):
                    if not self.zfs_manager.create_dataset(app_dataset):
                        self._handle_critical_failure(app_name, "Failed to create dataset")
                        return False

                self.logger.info(f"Ensuring {app_name} has {self.chart_info.get_version(app_name)} available in the chart directory...")
                self.version_restore.restore_to_chart_dir(app_name, self.chart_info.get_file(app_name, "chart_version"))

                self.logger.info(f"Restoring namespace for {app_name}...")
                if not self.restore_resources.restore_namespace(self.chart_info.get_file(app_name, "namespace")):
                    self.failures[app_name].append("Namespace restore failed")
                    self.logger.warning(f"Namespace restore failed, will attempt to create application instead")
                    self.create_list.append(app_name)

            pv_zfs_file = self.chart_info.get_file(app_name, "pv_zfs_volumes")
            if pv_zfs_file:
                self.logger.info(f"Restoring PV ZFS volumes for {app_name}...")
                pv_zfs_failures = self.restore_resources.restore_pv_zfs_volumes(pv_zfs_file)
                if pv_zfs_failures:
                    self.failures[app_name].extend(pv_zfs_failures)
                    self.logger.error(f"Failed to restore PV ZFS volumes for {app_name}.")

            if app_name in self.create_list:
                # Required, as "create" checks to see if the versions' directory exists
                self.logger.info(f"Deleting {app_name}'s versions directory")
                self.chart_version_utils.delete(app_name, self.chart_info.get_version(app_name))

                self.logger.info(f"Creating chart for {app_name}...")
                result = self.create_chart_manager.create(self.chart_info.get_file(app_name, "metadata"), self.chart_info.get_file(app_name, "values"))
                if not result["success"]:
                    self._handle_critical_failure(app_name, result["message"])
                    self.logger.error(f"Critical failure in restoring {app_name}, skipping further processing.\n")
                    return False

            app_secrets = self.chart_info.get_file(app_name, "secrets")
            if app_secrets:
                self.logger.info(f"Restoring secrets for {app_name}...")
                secret_failures = self.restore_resources.restore_secrets(app_secrets)
                if secret_failures:
                    self.failures[app_name].extend(secret_failures)

            if app_name not in self.create_list:
                try:
                    handle = self.middleware.call('chart.release.redeploy_internal', app_name, background=True, job=True)
                    self.logger.info(f"Redeploying {app_name}...")
                    self.job_handles.append((handle, app_name))
                except Exception as e:
                    self._handle_critical_failure(app_name, f"Failed to redeploy: {e}")
                    return False

            return True
        except Exception as e:
            self.logger.error(f"Exception during restoration of {app_name}: {e}")
            self.failures[app_name].append(f"Exception during restoration: {e}")
            return False

    def _build_restore_plan(self):
        """Check that all required items are present."""

        self.logger.info(f"Pool:")
        self.logger.info(f"  Name: {self.kube_config_reader.pool}\n")
        self.kube_config_reader.dataset 

        self.logger.info(f"Application Restore Plans:")
        for app_name in self.chart_info.all_releases:
            self.logger.info(f"  {app_name}")
            if not self.chart_info.get_file(app_name, "metadata"):
                self.critical_failures.append(app_name, "metadata file missing")
                self.logger.error(f"    Cannot Restore (metadata file missing)\n")
                self.chart_info.handle_critical_failure(app_name)
                continue
            elif not self.chart_info.get_file(app_name, "values"):
                self.critical_failures.append(app_name, "values file missing")
                self.logger.error(f"    Cannot Restore (values file missing)\n")
                self.chart_info.handle_critical_failure(app_name)
                continue

            if self.chart_info.get_chart_name(app_name) == "prometheus-operator":
                self.create_list.append(app_name)
                self.logger.info("    Will Create (prometheus-operator)")
            elif not self.chart_info.get_file(app_name, "namespace"):
                self.create_list.append(app_name)
                self.logger.info(f"    Will Create (namespace file missing)")
            else:
                self.logger.info(f"    Will Redeploy (namespace file present)")

            secrets_files = self.chart_info.get_file(app_name, "secrets")
            if secrets_files:
                self.logger.info(f"    Will Restore Secrets")
                for secret_file in secrets_files:
                    self.logger.info(f"      {secret_file.name}")

            pv_zfs_files = self.chart_info.get_file(app_name, "pv_zfs_volumes")
            if pv_zfs_files:
                self.logger.info(f"    Will Restore PV ZFS volumes")
                for pv_file in pv_zfs_files:
                    self.logger.info(f"      {pv_file.name}")

            database_file = self.chart_info.get_file(app_name, "database")
            if database_file:
                self.logger.info(f"    Will Restore Database")
                self.logger.info(f"      {database_file.name}")

            crd_files = self.chart_info.get_file(app_name, "crds")
            if crd_files:
                self.logger.info(f"    Will Restore CRDs")
                for crd_file in crd_files:
                    self.logger.info(f"      {crd_file.name}")
            self.logger.info("")

        user_input = input("Ensure everything looks correct. CNPG apps have their database listed, etc. Do you want to continue? (yes/no): ")
        if user_input.strip().lower() != 'yes':
            self.logger.info("User chose not to continue with the restore plan.")
            raise RuntimeError("Restore process aborted by the user.")

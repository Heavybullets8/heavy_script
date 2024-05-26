import os
from pathlib import Path
from collections import defaultdict
from app.app_manager import AppManager
from charts.backup_fetch import BackupChartFetcher
from charts.chart_version import ChartVersionUtils, ChartVersionRestore
from charts.backup_create import ChartCreationManager
from kube.config_parse import KubeConfigReader
from kube.resources_restore import KubeRestoreResources
from zfs.snapshot import ZFSSnapshotManager
from zfs.lifecycle import ZFSLifecycleManager
from utils.logger import setup_global_logger, set_logger
from utils.singletons import MiddlewareClientManager
from utils.type_check import type_check

class RestoreBase:
    def __init__(self, backup_dir: Path):
        """
        Initialize the RestoreBase class.

        Parameters:
        - backup_dir (Path): Directory where the backup is stored.
        """
        try:
            logger = setup_global_logger("restore")
            set_logger(logger)
            self.logger = logger
            self.logger.info("Restore process initialized.")

            self.backup_dir = backup_dir.resolve()
            self.snapshot_name = str(self.backup_dir.name)
            self.backup_dataset = str(self.backup_dir.relative_to("/mnt"))
            self.backup_chart_dir = self.backup_dir / "charts"
            self.catalog_dir = self.backup_dir / "catalog"

            print("Rolling back snapshot for backup dataset, ensuring integrity...")
            self.snapshot_manager = ZFSSnapshotManager()
            self.snapshot_manager.rollback_all_snapshots(self.snapshot_name, self.backup_dataset)

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
            raise RuntimeError("Failed to initialize RestoreBase class") from e

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

    def _restore_crds(self, app_name):
        self.logger.info(f"Restoring CRDs for {app_name}...")
        crd_failures = self.restore_resources.restore_crd(self.chart_info.get_file(app_name, "crds"))
        if crd_failures:
            self.failures[app_name].extend(crd_failures)

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

    @type_check
    def _restore_application(self, app_name: str) -> bool:
        """Restore a single application."""
        try:
            if app_name not in self.create_list:
                self.logger.info(f"Creating {app_name} dataset if needed...")
                app_dataset = os.path.join(self.kube_config_reader.dataset, "releases", app_name, "charts")
                app_volumes_dataset = os.path.join(self.kube_config_reader.dataset, "releases", app_name, "volumes", "ix_volumes")
                if not self.zfs_manager.dataset_exists(app_dataset):
                    if not self.zfs_manager.create_dataset(app_dataset):
                        self._handle_critical_failure(app_name, "Failed to create chart dataset")
                        return False

                if not self.zfs_manager.dataset_exists(app_volumes_dataset):
                    if not self.zfs_manager.create_dataset(app_volumes_dataset):
                        self._handle_critical_failure(app_name, "Failed to create volume dataset")
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

            cnpg_delete_file = self.chart_info.get_file(app_name, "cnpg_pvcs_to_delete")
            if cnpg_delete_file and cnpg_delete_file.exists():
                self._delete_cnpg_pvcs(cnpg_delete_file)

            return True
        except Exception as e:
            self.logger.error(f"Exception during restoration of {app_name}: {e}")
            self.failures[app_name].append(f"Exception during restoration: {e}")
            return False

    def _delete_cnpg_pvcs(self, delete_file: Path):
        """
        Delete CNPG PVC datasets listed in the delete file.

        Parameters:
            delete_file (Path): The file containing CNPG PVC dataset paths to delete.
        """
        self.logger.debug("Starting deletion of CNPG PVCs...")
        try:
            with open(delete_file, 'r') as f:
                datasets_to_delete = [line.strip() for line in f]

            for dataset in datasets_to_delete:
                if self.zfs_manager.dataset_exists(dataset):
                    self.logger.debug(f"Deleting CNPG PVC dataset: {dataset}")
                    if not self.zfs_manager.delete_dataset(dataset):
                        self.logger.error(f"Failed to delete dataset: {dataset}")
                else:
                    self.logger.warning(f"Dataset {dataset} does not exist, skipping deletion.")
        except Exception as e:
            self.logger.error(f"Error during CNPG PVC deletion: {e}", exc_info=True)


    def _build_restore_plan(self, app_names):
        """Check that all required items are present."""

        self.logger.info(f"Pool:")
        self.logger.info(f"  Name: {self.kube_config_reader.pool}\n")
        self.kube_config_reader.dataset 

        self.logger.info(f"Application Restore Plans:")
        for app_name in app_names:
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
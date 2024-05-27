from pathlib import Path
from catalog.catalog import CatalogRestoreManager
from database.restore import RestoreCNPGDatabase
from kube.utils import KubeUtils
from kube.config_restore import KubeRestoreConfig
from utils.utils import waitForKubernetes
from .restore_base import RestoreBase

class RestoreAll(RestoreBase):
    def __init__(self, backup_dir: Path):
        super().__init__(backup_dir)

    def restore(self):
        """Perform the entire restore process."""
        self.logger.info("Building Restore Plan\n"
                        "----------------------")
        try:
            self._build_restore_plan(self.chart_info.all_releases)
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

        if self.chart_info.cnpg_apps:
            self.logger.info("\nRestoring CNPG Databases\n"
                            "------------------------")
        for app_name in self.chart_info.cnpg_apps:
            try:
                self.logger.info(f"Restoring database for {app_name}...")
                db_manager = RestoreCNPGDatabase(app_name, self.chart_info.get_file(app_name, "database"))
                result = db_manager.restore()
                if not result["success"]:
                    self.failures[app_name].append(result["message"])
                else:
                    self.logger.info(result["message"])
            except Exception as e:
                self.logger.error(f"Failed to restore database for {app_name}: {e}")
                self.failures[app_name].append(f"Database restore failed: {e}")

        self._log_failures()

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

    def _start_kubernetes_services(self):
        """Start Kubernetes services after initial setup."""
        self.logger.info("Restoring Kubernetes configuration...")

        KubeRestoreConfig(self.kubernetes_config_file).restore()        

        if self.apps_dataset_exists:
            self.logger.info("Starting Kubernetes services...")
            KubeUtils().start_kubernetes_services()

        if not waitForKubernetes():
            raise Exception("Kubernetes failed to initialize.")
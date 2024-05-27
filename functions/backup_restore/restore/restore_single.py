from pathlib import Path
from catalog.catalog import CatalogRestoreManager
from database.restore import RestoreCNPGDatabase
from .restore_base import RestoreBase

class RestoreSingle(RestoreBase):
    def __init__(self, backup_dir: Path):
        super().__init__(backup_dir)
    
    def restore(self, app_names: list):
        """Perform the single application restore process."""
        self.logger.info("Building Restore Plan\n"
                        "----------------------")
        try:
            self._build_restore_plan(app_names)
        except RuntimeError as e:
            self.logger.error(str(e))
            return

        if not self.chart_info.all_releases:
            self.logger.error("No releases found in backup directory.")
            return

        self.logger.info("\nRolling Back Volume Snapshots\n"
                           "-----------------------------")
        for app_name in app_names:
            try:
                self._rollback_volumes(app_name)
                self.restore_snapshots(app_name)
            except Exception as e:
                self.logger.error(f"Failed to rollback snapshots for {app_name}: {e}\n")
                self.failures[app_name].append(f"Failed to rollback volume snapshots: {e}")

        self.logger.info("\nRestoring Catalogs\n"
                           "------------------")
        try:
            CatalogRestoreManager(self.catalog_dir).restore()
        except Exception as e:
            self.logger.warning(f"Failed to restore catalog: {e}")
            self.failures["Catalog"].append(f"Restoration failed: {e}")

        self.logger.info("\nRestoring Custom Resource Definitions\n"
                           "-------------------------------------")
        for app_name in app_names:
            if app_name in self.chart_info.apps_with_crds:
                self._restore_crds(app_name)

        self.logger.info("\nRestoring Applications\n"
                           "----------------------")

        cnpg_active = False
        self.job_handles = []

        for app_name in app_names:
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

        for app_name in app_names:
            if app_name in self.chart_info.cnpg_apps:
                self.logger.info("\nRestoring CNPG Databases\n"
                "------------------------")
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

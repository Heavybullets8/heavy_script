import os
import yaml
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
from utils.shell import run_command
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

            self.logger.info("Rolling back snapshot for backup dataset, ensuring integrity...")
            self.snapshot_manager = ZFSSnapshotManager()
            self.snapshot_manager.rollback_all_snapshots(self.snapshot_name, self.backup_dataset, recursive=True, force=True)

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
        self.failures.setdefault(app_name, []).append(error)
        if app_name not in self.critical_failures:
            self.critical_failures.append(app_name)
            self.chart_info.handle_critical_failure(app_name)

    def _restore_crds(self, app_name):
        """
        Restore CRDs for the specified application.

        Parameters:
        - app_name (str): The name of the application to restore CRDs for.
        """
        self.logger.info(f"Restoring CRDs for {app_name}...")
        crd_files = self.chart_info.get_file(app_name, "crds")

        for crd_file in crd_files:
            self.logger.debug(f"Restoring CRD from file: {crd_file}")
            restore_result = self.restore_resources.restore_crd(crd_file)
            if not restore_result["success"]:
                self.failures.setdefault(app_name, []).append(restore_result["message"])
                self.logger.error(f"Failed to restore CRD from {crd_file}: {restore_result['message']}")

    @type_check
    def _rollback_volumes(self, app_name: str):
        """
        Rollback persistent volumes or restore from backups if necessary.

        Parameters:
        - app_name (str): The name of the application to restore volumes for.
        """
        self.logger.debug(f"Starting rollback process for {app_name}...")

        def set_mountpoint_legacy(dataset_path):
            command = f"/sbin/zfs set mountpoint=legacy \"{dataset_path}\""
            result = run_command(command, suppress_output=True)
            if result.is_success():
                self.logger.debug(f"Set mountpoint to legacy for {dataset_path}")
            else:
                message = f"Failed to set mountpoint to legacy for {dataset_path}: {result.get_error()}"
                self.failures.setdefault(app_name, []).append(message)
                self.logger.error(message)

        def rollback_snapshot(snapshot: str, name: str, volume_type: str):
            self.logger.info(f"{app_name}: rolling back {volume_type} {name}...")
            rollback_result = self.snapshot_manager.rollback_snapshot(snapshot, recursive=True, force=True)
            if not rollback_result.get("success", False):
                self.failures.setdefault(app_name, []).append(rollback_result.get("message", "Unknown error"))
                self.logger.error(rollback_result.get("message", "Unknown error"))

        def restore_snapshot(snapshot: str, name: str, volume_type: str):
            self.logger.info(f"{app_name}: restoring {volume_type} {name} from backup...")
            snapshot_files = self.chart_info.get_file(app_name, "snapshots")
            if snapshot_files:
                for snapshot_file in snapshot_files:
                    snapshot_file_path = snapshot_file
                    snapshot_file_name = snapshot_file.stem.replace('%%', '/')
                    dataset_path, _ = snapshot_file_name.split('@', 1)
                    parent_dataset_path = '/'.join(dataset_path.split('/')[:-1])

                    if not self.zfs_manager.dataset_exists(parent_dataset_path):
                        self.logger.debug(f"Parent dataset {parent_dataset_path} does not exist. Creating it...")
                        if not self.zfs_manager.create_dataset(parent_dataset_path):
                            message = f"Failed to create parent dataset {parent_dataset_path}"
                            self.failures.setdefault(app_name, []).append(message)
                            self.logger.error(message)
                            continue

                    if snapshot_file_name == snapshot:
                        restore_result = self.snapshot_manager.zfs_receive(snapshot_file_path, dataset_path, decompress=True)
                        if not restore_result["success"]:
                            self.failures.setdefault(app_name, []).append(restore_result["message"])
                            self.logger.error(f"Failed to restore snapshot from {snapshot_file_path} for {app_name}: {restore_result['message']}")
            else:
                message = f"No snapshot files found for {app_name}"
                self.failures.setdefault(app_name, []).append(message)
                self.logger.error(message)

        # Process PV files
        pv_files = self.chart_info.get_file(app_name, "pv_zfs_volumes")
        self.logger.debug(f"Found PV files for {app_name}: {pv_files}")
        pv_only_files = [file for file in pv_files if file.name.endswith('-pv.yaml')]
        
        for pv_file in pv_only_files:
            try:
                with pv_file.open('r') as file:
                    pv_data = yaml.safe_load(file)
                self.logger.debug(f"Loaded PV data from {pv_file}: {pv_data}")
                pool_name = pv_data['spec']['csi']['volumeAttributes']['openebs.io/poolname']
                volume_handle = pv_data['spec']['csi']['volumeHandle']
                dataset_path = f"{pool_name}/{volume_handle}"
                snapshot = f"{dataset_path}@{self.snapshot_name}"
                pv_name = pv_file.stem

                self.logger.debug(f"Constructed snapshot path: {snapshot}")

                if self.snapshot_manager.snapshot_exists(snapshot):
                    rollback_snapshot(snapshot, pv_name, "PVC")
                elif any(snap.stem.replace('%%', '/') == snapshot for snap in self.chart_info.get_file(app_name, "snapshots") or []):
                    restore_snapshot(snapshot, pv_name, "PVC")
                else:
                    message = f"Snapshot {snapshot} for PVC {pv_name} cannot be rolled back or restored from backup."
                    self.failures.setdefault(app_name, []).append(message)
                    self.logger.error(message)
                    continue

                set_mountpoint_legacy(dataset_path)
            except Exception as e:
                message = f"Failed to process PV file {pv_file}: {e}"
                self.logger.error(message, exc_info=True)
                self.failures.setdefault(app_name, []).append(message)

        # Process ix_volumes
        ix_volumes_dataset = self.chart_info.get_ix_volumes_dataset(app_name)
        if ix_volumes_dataset:
            self.logger.debug(f"Found ix_volumes dataset for {app_name}: {ix_volumes_dataset}")
            snapshot = f"{ix_volumes_dataset}@{self.snapshot_name}"
            self.logger.debug(f"Constructed ix_volumes snapshot path: {snapshot}")

            if self.snapshot_manager.snapshot_exists(snapshot):
                rollback_snapshot(snapshot, "ix_volumes", "ix_volumes")
            elif any(snap.stem.replace('%%', '/') == snapshot for snap in self.chart_info.get_file(app_name, "snapshots") or []):
                restore_snapshot(snapshot, "ix_volumes", "ix_volumes")
            else:
                message = f"Snapshot {snapshot} for ix_volumes cannot be rolled back or restored from backup."
                self.failures.setdefault(app_name, []).append(message)
                self.logger.error(message)

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

                secret_files = self.chart_info.get_file(app_name, "secrets")
                if secret_files:
                    self.logger.info(f"Restoring secrets for {app_name}...")
                    for secret_file in secret_files:
                        secret_result = self.restore_resources.restore_secret(secret_file)
                        if not secret_result.get("success", False):
                            self.failures.setdefault(app_name, []).append(secret_result.get("message"))
                            self.logger.error(secret_result.get("message"))

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
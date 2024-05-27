from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict

from zfs.lifecycle import ZFSLifecycleManager
from zfs.snapshot import ZFSSnapshotManager
from utils.logger import setup_global_logger, set_logger
from utils.type_check import type_check
from database.backup import BackupCNPGDatabase
from catalog.catalog import CatalogBackupManager
from charts.backup_create import ChartBackupManager
from charts.api_fetch import APIChartFetcher, APIChartCollection
from charts.chart_version import ChartVersionBackup
from kube.config_backup import KubeBackupConfig
from kube.config_parse import KubeAPIFetch
from kube.resources_backup import KubeBackupResources
from pvc.api_fetch import KubePVCFetcher
from kube.utils import KubeUtils

class Backup:
    """
    Class responsible for managing the backup process of applications, including Kubernetes configurations, charts, and databases.
    """

    @type_check
    def __init__(self, backup_dir: Path, retention_number: int = 15):
        """
        Initialize the Backup class.

        Parameters:
        - backup_dir (Path): Directory to use for backups.
        - retention_number (int): Number of backups to retain. Defaults to 15.
        """
        logger = setup_global_logger("backup")
        set_logger(logger)
        self.logger = logger
        self.logger.info("Backup process initialized.")

        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d_%H:%M:%S')
        self.snapshot_name = f"HeavyScript--{timestamp}"
        self.kubeconfig = KubeAPIFetch()
        self.apps_pool = self.kubeconfig.pool
        self.retention_number = retention_number

        self.lifecycle_manager = ZFSLifecycleManager()
        self.snapshot_manager = ZFSSnapshotManager()

        self.backup_dir = backup_dir / self.snapshot_name

        self.backup_dataset_parent = self.backup_dir.relative_to("/mnt")
        self.backup_dataset = str(self.backup_dataset_parent)
        self._create_backup_dataset(self.backup_dataset)

        self.chart_collection = APIChartCollection()
        self.all_chart_names = self.chart_collection.all_chart_names
        self.all_release_names = self.chart_collection.all_release_names

        self.kube_pvc_fetcher = KubePVCFetcher()

    def _create_backup_dataset(self, dataset):
        """
        Create a ZFS dataset for backups if it doesn't already exist.
        """
        if not self.lifecycle_manager.dataset_exists(dataset):
            if not self.lifecycle_manager.create_dataset(dataset):
                raise RuntimeError(f"Failed to create backup dataset: {dataset}")

    def backup_all(self):
        """
        Perform all backup tasks.
        """
        self.logger.info(f"Backing up all applications to: {self.backup_dir}...")

        self.logger.info(f"Creating snapshots for {self.kubeconfig.dataset}...")
        self._backup_application_datasets()

        self.logger.info("Backing up catalog...")
        catalog_dir = self.backup_dir / "catalog"
        catalog_dir.mkdir(parents=True, exist_ok=True)
        CatalogBackupManager(catalog_dir).backup()

        self.logger.info("Backing up Kubernetes config...")
        kube_config_dir = self.backup_dir / "kubernetes_config"
        kube_config_dir.mkdir(parents=True, exist_ok=True)
        KubeBackupConfig(kube_config_dir).backup()

        failures = defaultdict(list)

        for app_name in self.all_release_names:
            self.logger.info(f"\nBacking up {app_name}...")
            app_backup_dir = self.backup_dir / "charts" / app_name
            app_backup_dir.mkdir(parents=True, exist_ok=True)

            chart_info = APIChartFetcher(app_name)
            if not chart_info.is_valid:
                self.logger.error(f"Failed to fetch chart data for {app_name}")
                failures[app_name].append("Failed to fetch chart data")
                continue

            self.logger.info(f"Backing up {app_name} chart version...")
            chart_versions = app_backup_dir / "chart_versions"
            chart_versions.mkdir(parents=True, exist_ok=True)
            if not ChartVersionBackup(chart_versions, app_name, self.apps_pool, chart_info.version).backup():
                failures[app_name].append("Failed to backup chart version")

            self.logger.info(f"Backing up {app_name} Kubernetes objects...")
            kubernetes_objects_path = app_backup_dir / "kubernetes_objects"
            kubernetes_objects_path.mkdir(parents=True, exist_ok=True)
            self.kube_backup_resources = KubeBackupResources(app_name, kubernetes_objects_path)

            if not self.kube_backup_resources.backup_namespace():
                failures[app_name].append("Failed to backup namespace")

            if not self.kube_backup_resources.backup_secrets():
                failures[app_name].append("Failed to backup secrets")

            if self.kube_pvc_fetcher.has_pvc(app_name):
                pvc_errors = self.kube_backup_resources.backup_pvcs()
                if pvc_errors:
                    failures[app_name].extend(pvc_errors)

            ix_crd_dir = Path(f"/mnt/{self.apps_pool}/ix-applications/releases/{app_name}/charts/{chart_info.version}/crds")
            if ix_crd_dir.exists():
                self.logger.info(f"Backing up {app_name} CRDs...")
                if not self.kube_backup_resources.backup_crd(ix_crd_dir):
                    failures[app_name].append("Failed to backup CRDs")

            self.logger.info(f"Backing up {app_name} chart...")
            chart_info_dir = app_backup_dir / "chart_info"
            chart_info_dir.mkdir(parents=True, exist_ok=True)
            self.backup_chart = ChartBackupManager(chart_info_dir)
            self.backup_chart.backup_metadata(app_name, chart_info.chart_name, chart_info.catalog, chart_info.train, chart_info.version)
            self.backup_chart.backup_values(app_name, chart_info.chart_config)

            if chart_info.is_cnpg:
                self.logger.info(f"Backing up {app_name} database...")
                app_database_dir = app_backup_dir / "database"
                app_database_dir.mkdir(parents=True, exist_ok=True)
                self.database_manager = BackupCNPGDatabase(app_database_dir, app_name)
                result = self.database_manager.backup()
                if not result["success"]:
                    self.logger.error(f"Failed to backup database for {app_name}: {result['message']}")
                    failures[app_name].append(result["message"])

            dataset_paths = self.kube_pvc_fetcher.get_volume_paths_by_namespace(f"ix-{app_name}")
            if dataset_paths:
                self.logger.info(f"Backing up {app_name} PVCs...")
                snapshot_result = self.snapshot_manager.create_snapshots(self.snapshot_name, dataset_paths, self.retention_number)
                if snapshot_result["errors"]:
                    failures[app_name].extend(snapshot_result["errors"])

                if snapshot_result["success"]:
                    for snapshot in snapshot_result["snapshots"]:
                        self.logger.info(f"Sending snapshot {snapshot} to backup directory...")
                        backup_path = app_backup_dir / "snapshots" / f"{snapshot.replace('/', '_')}.zfs"
                        backup_path.parent.mkdir(parents=True, exist_ok=True)
                        send_result = self.snapshot_manager.zfs_send(snapshot, backup_path, compress=True)
                        if not send_result["success"]:
                            failures[app_name].append(send_result["message"])

        self._create_backup_snapshot()
        self._log_failures(failures)
        self._cleanup_old_backups()

    def _log_failures(self, failures):
        """
        Log a summary of all backup failures.

        Parameters:
        - failures (dict): A dictionary of backup failures.
        """
        if not failures:
            self.logger.info("\nAll applications backed up successfully.")
            return

        self.logger.error("\nSome applications failed to backup:")
        for app_name, errors in failures.items():
            self.logger.error(f"{app_name}:")
            for error in errors:
                self.logger.error(f"  {error}")

    def _create_backup_snapshot(self):
        """
        Create a snapshot of the backup dataset after all backups are completed.
        """
        self.logger.info(f"\nCreating snapshot for backup: {self.backup_dataset}")
        snapshot_result = self.snapshot_manager.create_snapshots(self.snapshot_name, [self.backup_dataset], self.retention_number)

        if snapshot_result.get("success"):
            self.logger.info("Snapshot created successfully for backup dataset.")
        else:
            self.logger.error("Failed to create snapshot for backup dataset.")
            for error in snapshot_result.get("errors", []):
                self.logger.error(error)

    def _cleanup_old_backups(self):
        """
        Cleanup old backups and their associated snapshots if the number of backups exceeds the retention limit.
        """
        backup_datasets = sorted(
            (ds for ds in self.lifecycle_manager.list_datasets() if ds.startswith(f"{self.backup_dataset_parent}/HeavyScript--")),
            key=lambda ds: datetime.strptime(ds.replace(f"{self.backup_dataset_parent}/HeavyScript--", ""), '%Y-%m-%d_%H:%M:%S')
        )
        
        if len(backup_datasets) > self.retention_number:
            for old_backup_dataset in backup_datasets[:-self.retention_number]:
                snapshot_name = old_backup_dataset.split("/")[-1]
                self.logger.info(f"Deleting oldest backup due to retention limit: {snapshot_name}")
                try:
                    self.lifecycle_manager.delete_dataset(old_backup_dataset)
                    self.logger.debug(f"Removed old backup: {old_backup_dataset}")
                except Exception as e:
                    self.logger.error(f"Failed to delete old backup dataset {old_backup_dataset}: {e}", exc_info=True)
                
                self.logger.debug(f"Deleting snapshots for: {snapshot_name}")
                snapshot_errors = self.snapshot_manager.delete_snapshots(snapshot_name)
                if snapshot_errors:
                    self.logger.error(f"Failed to delete snapshots for {snapshot_name}: {snapshot_errors}")

    def _backup_application_datasets(self):
        """
        Backup all datasets within the specified application dataset, except for those specified in to_ignore_datasets_on_backup.

        Parameters:
        - applications_dataset (str): The root dataset under which Kubernetes operates.
        """
        datasets_to_ignore = KubeUtils().to_ignore_datasets_on_backup(self.kubeconfig.dataset)
        all_datasets = self.lifecycle_manager.list_datasets()

        datasets_to_backup = [ds for ds in all_datasets if ds.startswith(self.kubeconfig.dataset) and ds not in datasets_to_ignore]
        self.logger.debug(f"Snapshotting datasets: {datasets_to_backup}")

        snapshot_result = self.snapshot_manager.create_snapshots(self.snapshot_name, datasets_to_backup, self.retention_number)
        if not snapshot_result.get("success"):
            self.logger.error("Failed to create snapshots for application datasets.")
            for error in snapshot_result.get("errors", []):
                self.logger.error(error)
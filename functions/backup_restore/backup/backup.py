from datetime import datetime, timezone
from configobj import ConfigObj
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
        self._create_backup_dataset()

        self.chart_collection = APIChartCollection()
        self.all_chart_names = self.chart_collection.all_chart_names
        self.all_release_names = self.chart_collection.all_release_names

        self.kube_pvc_fetcher = KubePVCFetcher()

        # Read configuration settings
        config_file_path = str(Path(__file__).parent.parent.parent.parent / 'config.ini')
        config = ConfigObj(config_file_path, encoding='utf-8', list_values=False)

        self.backup_snapshot_streams = config['BACKUP'].as_bool('backup_snapshot_streams')
        self.max_stream_size_str = config['BACKUP'].get('max_stream_size', '10G')
        self.max_stream_size_bytes = self._size_str_to_bytes(self.max_stream_size_str)

    def _create_backup_dataset(self):
        """
        Create a ZFS dataset for backups.
        """
        if not self.lifecycle_manager.dataset_exists(self.backup_dataset):
            if not self.lifecycle_manager.create_dataset(
                self.backup_dataset,
                options={
                    "atime": "off",
                    "compression": "zstd-19",
                    "recordsize": "1M"
                }
            ):
                raise RuntimeError(f"Failed to create backup dataset: {self.backup_dataset}")

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
                for dataset_path in dataset_paths:
                    pvc_name = dataset_path.split('/')[-1]
                    self.logger.info(f"Snapshotting PVC: {pvc_name}...")

                    # Check to see if dataset exists
                    if not self.lifecycle_manager.dataset_exists(dataset_path):
                        error_msg = f"Dataset {dataset_path} does not exist."
                        self.logger.error(error_msg)
                        failures[app_name].append(error_msg)
                        continue

                    # Create the snapshot for the current dataset
                    snapshot_result = self.snapshot_manager.create_snapshot(self.snapshot_name, dataset_path)
                    if not snapshot_result["success"]:
                        failures[app_name].append(snapshot_result["message"])
                        continue

                    self.logger.debug(f"backup_snapshot_streams: {self.backup_snapshot_streams}")
                    self.logger.debug(f"max_stream_size_str: {self.max_stream_size_str}")
                    self.logger.debug(f"max_stream_size_bytes: {self.max_stream_size_bytes}")

                    if self.backup_snapshot_streams:
                        snapshot = f"{dataset_path}@{self.snapshot_name}"
                        snapshot_refer_size = self.snapshot_manager.get_snapshot_refer_size(snapshot)
                        self.logger.debug(f"snapshot_refer_size: {snapshot_refer_size}")

                        if snapshot_refer_size <= self.max_stream_size_bytes:
                            # Send the snapshot to the backup directory
                            self.logger.info(f"Sending PV snapshot stream to backup file...")
                            snapshot = f"{dataset_path}@{self.snapshot_name}"
                            backup_path = app_backup_dir / "snapshots" / f"{snapshot.replace('/', '%%')}.zfs"
                            backup_path.parent.mkdir(parents=True, exist_ok=True)
                            send_result = self.snapshot_manager.zfs_send(snapshot, backup_path, compress=True)
                            if not send_result["success"]:
                                failures[app_name].append(send_result["message"])
                        else:
                            self.logger.warning(f"Snapshot refer size {snapshot_refer_size} exceeds the maximum configured size {self.max_stream_size_bytes}")
                    else:
                        self.logger.debug("Backup snapshot streams are disabled in the configuration.")

            # Handle ix_volumes_dataset separately
            if chart_info.ix_volumes_dataset:
                snapshot = chart_info.ix_volumes_dataset + "@" + self.snapshot_name
                if self.backup_snapshot_streams:
                    snapshot_refer_size = self.snapshot_manager.get_snapshot_refer_size(snapshot)
                    self.logger.debug(f"ix_volumes_dataset snapshot_refer_size: {snapshot_refer_size}")

                    if snapshot_refer_size <= self.max_stream_size_bytes:
                        self.logger.info(f"Sending ix_volumes snapshot stream to backup file...")
                        backup_path = app_backup_dir / "snapshots" / f"{snapshot.replace('/', '%%')}.zfs"
                        backup_path.parent.mkdir(parents=True, exist_ok=True)
                        send_result = self.snapshot_manager.zfs_send(snapshot, backup_path, compress=True)
                        if not send_result["success"]:
                            failures[app_name].append(send_result["message"])
                    else:
                        self.logger.warning(f"ix_volumes_dataset snapshot refer size {snapshot_refer_size} exceeds the maximum configured size {self.max_stream_size_bytes}")
                else:
                    self.logger.debug("Backup snapshot streams are disabled in the configuration.")

        self._create_backup_snapshot()
        self._log_failures(failures)

    def _size_str_to_bytes(self, size_str):
        size_units = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
        try:
            if size_str[-1] in size_units:
                return int(float(size_str[:-1]) * size_units[size_str[-1]])
            else:
                return int(size_str)
        except ValueError:
            self.logger.error(f"Invalid size string: {size_str}")
            return 0

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
        snapshot_result = self.snapshot_manager.create_snapshot(self.snapshot_name, self.backup_dataset)

        if snapshot_result.get("success"):
            self.logger.info("Snapshot created successfully for backup dataset.")
        else:
            self.logger.error("Failed to create snapshot for backup dataset.")
            for error in snapshot_result.get("errors", []):
                self.logger.error(error)

    def _backup_application_datasets(self):
        """
        Backup all datasets within the specified application dataset, except for those specified in to_ignore_datasets_on_backup.

        Parameters:
        - applications_dataset (str): The root dataset under which Kubernetes operates.
        """
        datasets_to_ignore = KubeUtils().to_ignore_datasets_on_backup(self.kubeconfig.dataset)

        datasets_to_backup = [ds for ds in self.lifecycle_manager.datasets if ds.startswith(self.kubeconfig.dataset) and ds not in datasets_to_ignore]
        self.logger.debug(f"Snapshotting datasets: {datasets_to_backup}")

        for dataset in datasets_to_backup:
            # Create snapshot for each dataset
            snapshot_result = self.snapshot_manager.create_snapshot(self.snapshot_name, dataset)
            if not snapshot_result.get("success"):
                self.logger.error(f"Failed to create snapshot for dataset {dataset}: {snapshot_result['message']}")
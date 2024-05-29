import re
import shutil
from datetime import datetime
from pathlib import Path
from zfs.lifecycle import ZFSLifecycleManager
from zfs.snapshot import ZFSSnapshotManager
from utils.logger import get_logger

class BaseManager:
    def __init__(self, backup_abs_path: Path):
        self.logger = get_logger()
        self.backup_abs_path = backup_abs_path.resolve()
        self.backup_dataset_parent = self._derive_dataset_parent()
        self.lifecycle_manager = ZFSLifecycleManager()
        self.snapshot_manager = ZFSSnapshotManager()
        self.logger.debug(f"Initializing BaseManager for path: {self.backup_abs_path}")

        if not self.lifecycle_manager.dataset_exists(self.backup_dataset_parent):
            self.lifecycle_manager.create_dataset(self.backup_dataset_parent)
            self.logger.debug(f"Created dataset: {self.backup_dataset_parent}")

    def _derive_dataset_parent(self):
        """Derive the ZFS dataset path from the absolute path."""
        derived_path = str(self.backup_abs_path).replace("/mnt/", "")
        self.logger.debug(f"Derived dataset parent: {derived_path}")
        return derived_path

    def list_backups(self):
        """List all backups in the parent dataset, separated into full backups and exports."""
        self.logger.debug("Listing all backups")
        full_backups = sorted(
            (ds for ds in self.lifecycle_manager.list_datasets() if ds.startswith(f"{self.backup_dataset_parent}/HeavyScript--")),
            key=lambda ds: datetime.strptime(ds.split('/')[-1].replace("HeavyScript--", ""), '%Y-%m-%d_%H:%M:%S'),
            reverse=True
        )

        export_dirs = sorted(
            (dir for dir in self.backup_abs_path.iterdir() if dir.is_dir() and dir.name.startswith("Export--")),
            key=lambda dir: datetime.strptime(dir.name.replace("Export--", ""), '%Y-%m-%d_%H:%M:%S'),
            reverse=True
        )

        self.logger.debug(f"Found {len(full_backups)} full backups and {len(export_dirs)} export directories")
        return full_backups, export_dirs

    def _list_snapshots_for_backup(self, backup_name: str):
        """List all snapshots matching a specific backup name."""
        self.logger.debug(f"Listing snapshots for backup: {backup_name}")
        all_snapshots = self.snapshot_manager.list_snapshots()
        pattern = re.compile(r'HeavyScript--\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}')
        matching_snapshots = [snap for snap in all_snapshots if pattern.search(snap) and snap.endswith(f"@{backup_name}")]
        self.logger.debug(f"Found {len(matching_snapshots)} snapshots for backup: {backup_name}")
        return matching_snapshots

    def delete_backup(self, backup_name: str):
        """Delete a specific backup and its associated snapshots by name."""
        full_backups, export_dirs = self.list_backups()

        for backup in full_backups:
            if backup.endswith(backup_name):
                self.logger.info(f"Deleting full backup: {backup}")
                self.lifecycle_manager.delete_dataset(backup)
                snapshots = self._list_snapshots_for_backup(backup_name)
                for snapshot in snapshots:
                    self.snapshot_manager.delete_snapshot(snapshot)
                self.logger.info(f"Deleted full backup: {backup} and associated snapshots")
                return True

        for export in export_dirs:
            if export.name == backup_name:
                self.logger.info(f"Deleting export: {export}")
                shutil.rmtree(export)
                self.logger.info(f"Deleted export: {export}")
                return True

        self.logger.info(f"Backup {backup_name} not found")
        return False

    def delete_old_backups(self, retention: int):
        """Delete backups that exceed the retention limit."""
        self.logger.debug(f"Deleting old backups exceeding retention: {retention}")
        full_backups, _ = self.list_backups()
        if len(full_backups) > retention:
            for backup in full_backups[retention:]:
                backup_name = Path(backup).name
                self.delete_backup(backup_name)

    def interactive_select_backup(self, backup_type="all"):
        """
        Offer an interactive selection of backups.

        Parameters:
        - backup_type (str): The type of backups to display. Options are "all", "full", or "export".
        """
        self.logger.debug(f"Interactive selection of backups of type: {backup_type}")
        full_backups, export_dirs = self.list_backups()
        
        if backup_type == "full":
            backups_to_display = full_backups
            index_start = 1
        elif backup_type == "export":
            backups_to_display = export_dirs
            index_start = 1
        else:
            backups_to_display = full_backups + export_dirs
            index_start = 1

        if not backups_to_display:
            self.logger.info("No backups found")
            return None

        self.logger.info("Available backups:")
        if backup_type in ["all", "full"] and full_backups:
            self.logger.info("Full Backups")
            for i, backup in enumerate(full_backups, index_start):
                backup_name = Path(backup).name
                self.logger.info(f"{i:>2}) {backup_name}")
            index_start += len(full_backups)

        if backup_type in ["all", "export"] and export_dirs:
            if backup_type == "all":
                if export_dirs:
                    self.logger.info("Exports")
            for i, export in enumerate(export_dirs, index_start):
                self.logger.info(f"{i:>2}) {export.name}")

        try:
            backup_index = int(input("Enter the number of the backup to select: ").strip()) - 1
            if backup_type == "export":
                all_backups = export_dirs
            elif backup_type == "full":
                all_backups = full_backups
            else:
                all_backups = full_backups + export_dirs

            if 0 <= backup_index < len(all_backups):
                self.logger.debug(f"Selected backup: {all_backups[backup_index]}")
                return all_backups[backup_index]
            else:
                self.logger.info("Invalid selection")
                return None
        except KeyboardInterrupt:
            self.logger.info("Operation cancelled by user")
            return None
        except ValueError:
            self.logger.info("Invalid input, not a number")
            return None

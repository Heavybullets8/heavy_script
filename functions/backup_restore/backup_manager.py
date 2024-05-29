import re
import shutil
from pathlib import Path
from base_manager import BaseManager
from backup.backup import Backup
from backup.export_ import ChartInfoExporter
from utils.logger import get_logger

class BackupManager(BaseManager):
    def __init__(self, backup_abs_path: Path):
        super().__init__(backup_abs_path)
        self.logger = get_logger()
        self.logger.info(f"BackupManager initialized for {self.backup_abs_path}")

    def backup_all(self, retention=None):
        """Perform a full backup of the system with optional retention."""
        self.logger.info("Starting full backup operation")
        backup = Backup(self.backup_abs_path)
        backup.backup_all()
        self.logger.info("Backup completed successfully")
        self.cleanup_dangling_snapshots()
        if retention is not None:
            self.delete_old_backups(retention)

    def export_chart_info(self, retention=None):
        """Export chart information with optional retention."""
        self.logger.info("Starting chart information export")
        exporter = ChartInfoExporter(self.backup_abs_path)
        exporter.export()
        self.logger.info("Chart information export completed successfully")
        if retention is not None:
            self.delete_old_exports(retention)

    def delete_backup_by_name(self, backup_name: str):
        """Delete a specific backup by name."""
        self.logger.info(f"Attempting to delete backup: {backup_name}")
        result = self.delete_backup(backup_name)
        if result:
            self.logger.info(f"Deleted backup: {backup_name}")
        else:
            self.logger.info(f"Backup {backup_name} not found")

    def delete_backup_by_index(self, backup_index: int):
        """Delete a specific backup by index."""
        self.logger.info(f"Attempting to delete backup by index: {backup_index}")
        full_backups, export_dirs = self.list_backups()
        all_backups = full_backups + export_dirs

        if 0 <= backup_index < len(all_backups):
            backup = all_backups[backup_index]
            backup_name = Path(backup).name
            self.logger.info(f"Deleting backup: {backup_name}")
            self.delete_backup(backup_name)
            self.logger.info(f"Deleted backup: {backup_name}")
        else:
            self.logger.info(f"Invalid backup index: {backup_index}")

    def interactive_delete_backup(self):
        """Offer an interactive selection to delete backups."""
        self.logger.info("Starting interactive backup deletion")
        selected_backup = self.interactive_select_backup()
        if selected_backup:
            backup_name = Path(selected_backup).name
            self.delete_backup_by_name(backup_name)

    def display_backups(self):
        """Display all backups without deleting them."""
        self.logger.info("Displaying all backups")
        full_backups, export_dirs = self.list_backups()
        if not full_backups and not export_dirs:
            self.logger.info("No backups found")
            return

        print("Available backups:")
        if full_backups:
            print("Full Backups")
        for i, backup in enumerate(full_backups, 1):
            backup_name = Path(backup).name
            print(f"{i}) {backup_name}")

        if export_dirs:
            print("\nExports")
        for i, export in enumerate(export_dirs, len(full_backups) + 1):
            print(f"{i}) {export.name}")

    def cleanup_dangling_snapshots(self):
        """Remove dangling snapshots that do not match any full backup names."""
        self.logger.debug("Cleaning up dangling snapshots")
        full_backups, _ = self.list_backups()
        full_backup_names = {Path(backup).name for backup in full_backups}

        pattern = re.compile(r'HeavyScript--\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}')

        for snapshot in self.snapshot_manager.snapshots:
            match = pattern.search(snapshot)
            if match:
                snapshot_name = match.group()
                if snapshot_name not in full_backup_names:
                    self.logger.info(f"Deleting dangling snapshot: {snapshot}")
                    delete_result = self.snapshot_manager.delete_snapshot(snapshot)
                    if delete_result["success"]:
                        self.logger.info(f"Deleted snapshot: {snapshot}")
                    else:
                        self.logger.error(f"Failed to delete snapshot {snapshot}: {delete_result['message']}")

    def delete_old_exports(self, retention):
        """Delete exports that exceed the retention limit."""
        self.logger.debug(f"Deleting old exports exceeding retention: {retention}")
        _, export_dirs = self.list_backups()
        if len(export_dirs) > retention:
            for export in export_dirs[retention:]:
                self.logger.info(f"Deleting old export: {export.name}")
                shutil.rmtree(export)
                self.logger.info(f"Deleted old export: {export.name}")

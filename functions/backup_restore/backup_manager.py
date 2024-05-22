import re
import shutil
from pathlib import Path
from base_manager import BaseManager
from backup.backup import Backup
from backup.export_ import ChartInfoExporter
from zfs.snapshot import ZFSSnapshotManager

class BackupManager(BaseManager):
    def __init__(self, backup_abs_path: Path):
        super().__init__(backup_abs_path)
        self.snapshot_manager = ZFSSnapshotManager()

    def backup_all(self, retention=None):
        """Perform a full backup of the system with optional retention."""
        backup = Backup(self.backup_abs_path)
        backup.backup_all()
        print("Backup completed successfully.")
        self.cleanup_dangling_snapshots()
        if retention is not None:
            self.delete_old_backups(retention)

    def export_chart_info(self, retention=None):
        """Export chart information with optional retention."""
        exporter = ChartInfoExporter(self.backup_abs_path)
        exporter.export()
        print("Chart information export completed successfully.")
        self.cleanup_dangling_snapshots()
        if retention is not None:
            self.delete_old_exports(retention)

    def delete_backup_by_name(self, backup_name: str):
        """Delete a specific backup by name."""
        full_backups, export_dirs = self.list_backups()

        for backup in full_backups:
            if backup.endswith(backup_name):
                print(f"Deleting full backup: {backup}")
                self.lifecycle_manager.delete_dataset(backup)
                self.snapshot_manager.delete_snapshots(backup_name)
                print(f"Deleted full backup: {backup} and associated snapshots.")
                self.cleanup_dangling_snapshots()
                return True

        for export in export_dirs:
            if export.name == backup_name:
                print(f"Deleting export: {export}")
                shutil.rmtree(export)
                print(f"Deleted export: {export}")
                self.cleanup_dangling_snapshots()
                return True

        print(f"Backup {backup_name} not found.")
        return False

    def delete_backup_by_index(self, backup_index: int):
        """Delete a specific backup by index."""
        full_backups, export_dirs = self.list_backups()
        all_backups = full_backups + export_dirs

        if 0 <= backup_index < len(all_backups):
            backup = all_backups[backup_index]
            if backup in full_backups:
                backup_name = Path(backup).name
                print(f"Deleting full backup: {backup_name}")
                self.lifecycle_manager.delete_dataset(backup)
                self.snapshot_manager.delete_snapshots(backup_name)
                print(f"Deleted full backup: {backup_name} and associated snapshots.")
            elif backup in export_dirs:
                print(f"Deleting export: {backup.name}")
                shutil.rmtree(backup)
                print(f"Deleted export: {backup.name}")
            self.cleanup_dangling_snapshots()
            return True

        print(f"Invalid backup index: {backup_index}")
        return False

    def interactive_delete_backup(self):
        """Offer an interactive selection to delete backups."""
        selected_backup = self.interactive_select_backup()
        if selected_backup:
            all_backups = self.list_backups()[0] + self.list_backups()[1]
            backup_index = all_backups.index(selected_backup)
            self.delete_backup_by_index(backup_index)

    def display_backups(self):
        """Display all backups without deleting them."""
        full_backups, export_dirs = self.list_backups()
        if not full_backups and not export_dirs:
            print("No backups found.")
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
        full_backups, _ = self.list_backups()
        full_backup_names = {Path(backup).name for backup in full_backups}

        all_snapshots = self.snapshot_manager.list_snapshots()
        pattern = re.compile(r'HeavyScript--\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}')
        deleted_snapshots = set()

        for snapshot in all_snapshots:
            match = pattern.search(snapshot)
            if match:
                snapshot_name = match.group()
                if snapshot_name not in full_backup_names and snapshot_name not in deleted_snapshots:
                    print(f"Deleting dangling snapshot: {snapshot_name}")
                    self.snapshot_manager.delete_snapshots(snapshot_name)
                    print(f"Deleted snapshot: {snapshot_name}")
                    deleted_snapshots.add(snapshot_name)

    def delete_old_backups(self, retention):
        """Delete backups that exceed the retention limit."""
        full_backups, _ = self.list_backups()
        if len(full_backups) > retention:
            for backup in full_backups[retention:]:
                backup_name = Path(backup).name
                print(f"Deleting old backup: {backup_name}")
                self.lifecycle_manager.delete_dataset(backup)
                self.snapshot_manager.delete_snapshots(backup_name)
                print(f"Deleted old backup: {backup_name} and associated snapshots.")

    def delete_old_exports(self, retention):
        """Delete exports that exceed the retention limit."""
        _, export_dirs = self.list_backups()
        if len(export_dirs) > retention:
            for export in export_dirs[retention:]:
                print(f"Deleting old export: {export.name}")
                shutil.rmtree(export)
                print(f"Deleted old export: {export.name}")

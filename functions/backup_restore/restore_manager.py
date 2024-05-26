from base_manager import BaseManager
from restore.restore_all import RestoreAll
from restore.restore_single import RestoreSingle
from restore.import_ import ChartInfoImporter
from pathlib import Path
from utils.logger import get_logger

class RestoreManager(BaseManager):
    def __init__(self, backup_abs_path: Path):
        super().__init__(backup_abs_path)
        logger = get_logger()
        self.logger = logger

    def remove_newer_backups(self, backup_name: str):
        """Remove backups that are newer than the current backup dataset."""
        self.logger.info(f"Removing backups newer than: {backup_name}")
        full_backups, _ = self.list_backups()
        restore_index = next((i for i, ds in enumerate(full_backups) if ds.endswith(backup_name)), None)

        if restore_index is None:
            self.logger.info(f"Backup {backup_name} not found in the list of full backups.")
            return False

        if restore_index > 0:
            newer_backups = full_backups[:restore_index]
            self.logger.info("You have selected a backup that is not the most recent one.")
            self.logger.info("When a snapshot rollback occurs, any newer snapshots will be destroyed.")
            self.logger.info("This means that the newer backups will be incomplete and cannot be used.")
            self.logger.info("As a result, the following newer backups will be deleted along with their snapshots:")
            for backup in newer_backups:
                newer_backup_name = Path(backup).name
                self.logger.info(f"  {newer_backup_name}")

            confirm = input("Do you want to proceed with deleting these backups? (yes/no): ").strip().lower()
            if confirm != 'yes':
                self.logger.info("Operation cancelled by user.")
                return False

            for backup in newer_backups:
                newer_backup_name = Path(backup).name
                self.logger.info(f"Deleting newer backup due to restore: {newer_backup_name}")
                self.lifecycle_manager.delete_dataset(backup)
                self.snapshot_manager.delete_snapshots(newer_backup_name)
                self.logger.info(f"Deleted backup: {newer_backup_name} and associated snapshots.")

        return True

    def restore_all(self, backup_name: str):
        """Restore all from the specified backup."""
        self.logger.info("Warning: 'restore_all' should only be used as a last resort or when specifically instructed. Proceed with caution.")
        confirm = input("Do you want to continue with 'restore_all'? (yes/no): ").strip().lower()
        if confirm != 'yes':
            self.logger.info("Operation cancelled by user.")
            return

        if not self.remove_newer_backups(backup_name):
            return

        self.logger.info("Initiating full restore...")
        RestoreAll(self.backup_abs_path / backup_name).restore()
        self.logger.info("Restore All completed successfully.")

    def restore_single(self, backup_name: str, app_name: str = None):
        """Restore a single application from the specified backup."""
        if not app_name:
            app_name = self.interactive_select_chart(backup_name)
            if not app_name:
                return
        
        self.logger.info(f"Initiating restore for {app_name} from {backup_name}...")
        RestoreSingle(self.backup_abs_path / backup_name).restore([app_name])
        self.logger.info(f"Restore Single for {app_name} completed successfully.")

    def import_chart(self, backup_name: str, app_name: str = None):
        """Import a specific chart from the specified backup."""
        if app_name:
            self.logger.info(f"Initiating import for {app_name}...")
            if ChartInfoImporter(app_name, self.backup_abs_path / backup_name).import_chart_info():
                self.logger.info(f"Imported {app_name} successfully.")
            else:
                self.logger.info(f"Failed to import {app_name}.")
        else:
            app_name = self.interactive_select_chart(backup_name)
            if app_name:
                self.import_chart(backup_name, app_name)

    def interactive_restore(self, restore_type: str):
        """Offer an interactive selection to restore backups."""
        self.logger.info(f"Interactive restore of type: {restore_type}")
        backup_type = "full" if restore_type in ['restore_all', 'restore_single'] else "export"
        selected_backup = self.interactive_select_backup(backup_type)
        if selected_backup:
            backup_name = Path(selected_backup).name
            if restore_type == 'restore_all':
                self.restore_all(backup_name)
            elif restore_type == 'restore_single':
                self.restore_single(backup_name)

    def interactive_select_chart(self, backup_name: str) -> str:
        """Offer an interactive selection of charts for import or single restore."""
        charts_dir = self.backup_abs_path / backup_name / "charts"
        if not charts_dir.exists():
            self.logger.info(f"No charts directory found in {backup_name}.")
            return None

        charts = sorted(chart.name for chart in charts_dir.iterdir() if chart.is_dir())
        if not charts:
            self.logger.info(f"No charts found in {backup_name}.")
            return None

        self.logger.info(f"Available charts in {backup_name}:")
        for i, chart in enumerate(charts, 1):
            self.logger.info(f"  {i}) {chart}")

        try:
            chart_index = int(input("Enter the number of the chart to restore/import: ").strip()) - 1
            if 0 <= chart_index < len(charts):
                return charts[chart_index]
            else:
                self.logger.info("Invalid selection.")
                return None
        except KeyboardInterrupt:
            self.logger.info("Operation cancelled by user")
            return None
        except ValueError:
            self.logger.info("Invalid input. Please enter a number.")
            return None

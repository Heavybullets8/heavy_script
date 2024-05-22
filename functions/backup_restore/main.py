import argparse
from pathlib import Path
from backup_manager import BackupManager
from restore_manager import RestoreManager

def main():
    parser = argparse.ArgumentParser(description="Backup and Restore Manager")
    parser.add_argument("dataset_abs_path", type=Path, help="The absolute path to the dataset parent (e.g., /mnt/POOL/DATASET).")
    parser.add_argument("action", choices=["backup_all", "export", "restore_all", "import", "delete", "list"], help="Action to perform.")
    parser.add_argument("backup_name", nargs="?", default=None, help="The name of the backup to perform the action on.")
    parser.add_argument("app_name", nargs="?", default=None, help="The name of the chart to import (only for 'import' action).")
    parser.add_argument("--retention", type=int, default=None, help="The number of backups to retain.")

    args = parser.parse_args()

    dataset_abs_path = args.dataset_abs_path.resolve()
    action = args.action
    backup_name = args.backup_name
    app_name = args.app_name
    retention = args.retention

    if action in ["backup_all", "export"]:
        utility = BackupManager(dataset_abs_path)
        if action == "backup_all":
            utility.backup_all(retention)
        elif action == "export":
            utility.export_chart_info(retention)
    elif action in ["restore_all", "import"]:
        utility = RestoreManager(dataset_abs_path)
        if backup_name:
            if action == "restore_all":
                utility.restore_all(backup_name)
            elif action == "import":
                utility.import_chart(backup_name, app_name)
        else:
            utility.interactive_restore(action)
    elif action == "delete":
        utility = BackupManager(dataset_abs_path)
        if backup_name:
            utility.delete_backup_by_name(backup_name)
        else:
            utility.interactive_delete_backup()
    elif action == "list":
        utility = BackupManager(dataset_abs_path)
        utility.display_backups()

if __name__ == "__main__":
    main()

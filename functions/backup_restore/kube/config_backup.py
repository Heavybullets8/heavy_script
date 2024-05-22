import json
import logging
from pathlib import Path
from utils.singletons import MiddlewareClientManager
from utils.type_check import type_check

class KubeBackupConfig:
    @type_check
    def __init__(self, backup_dir: Path):
        """
        Initialize the KubeBackupConfig class.

        Parameters:
        - backup_dir (Path): Directory where the backup will be stored.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.middleware = MiddlewareClientManager.fetch()
        self.backupDir = backup_dir
        self.logger.debug(f"KubeBackupConfig initialized with backup directory: {self.backupDir}")

    def backup(self):
        """
        Backup the current Kubernetes configuration to the specified directory.

        Writes the Kubernetes configuration to a JSON file in the backup directory.
        """
        self.logger.debug("Starting Kubernetes configuration backup...")
        try:
            config = self.middleware.call('kubernetes.config')
            backup_path = self.backupDir / 'kubernetes_config.json'
            self.logger.debug(f"Writing Kubernetes configuration to {backup_path}")
            with open(backup_path, 'w') as f:
                json.dump(config, f, indent=4)
            self.logger.debug(f"Successfully backed up Kubernetes configuration to {backup_path}")
        except Exception as e:
            self.logger.error(f"Failed to backup Kubernetes configuration: {e}", exc_info=True)

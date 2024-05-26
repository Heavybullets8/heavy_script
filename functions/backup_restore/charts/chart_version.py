from pathlib import Path
import shutil
import tarfile
from utils.logger import get_logger
from utils.type_check import type_check

class ChartVersionBackup:
    """
    Class responsible for backing up chart versions.
    """

    @type_check
    def __init__(self, backup_dir: Path, app_name: str, ix_apps_pool: str, version: str):
        """
        Initialize the ChartVersionBackup class.

        Parameters:
            backup_dir (Path): Directory where backups will be stored.
            app_name (str): Name of the application.
            ix_apps_pool (str): Pool of ix-applications.
            version (str): Version of the chart to backup.
        """
        self.logger = get_logger()
        self.backup_dir = backup_dir
        self.app_name = app_name
        self.ix_apps_pool = ix_apps_pool
        self.version = version
        self.logger.debug(f"ChartVersionBackup initialized for app: {self.app_name}, version: {self.version}, backup directory: {self.backup_dir}, pool: {self.ix_apps_pool}")

    def backup(self) -> bool:
        """
        Backup the specified chart version.

        Returns:
            bool: True if backup is successful, False otherwise.
        """
        app_version_dir = Path(f"/mnt/{self.ix_apps_pool}/ix-applications/releases/{self.app_name}/charts/{self.version}")
        backup_version_file = self.backup_dir / f"{self.version}.tar.gz"

        self.logger.debug(f"Starting backup for app: {self.app_name}, version: {self.version}, from {app_version_dir} to {backup_version_file}")

        if app_version_dir.exists() and app_version_dir.is_dir():
            try:
                with tarfile.open(backup_version_file, 'w:gz') as tar:
                    for item in app_version_dir.iterdir():
                        tar.add(item, arcname=item.name)
                self.logger.debug(f"Compressed {app_version_dir} to {backup_version_file}")
                return True
            except Exception as e:
                self.logger.error(f"Failed to backup chart versions for {self.app_name}: {e}", exc_info=True)
                return False
        else:
            self.logger.warning(f"Source directory does not exist: {app_version_dir}")
            return False

class ChartVersionRestore:
    """
    Class responsible for restoring chart versions.
    """

    @type_check
    def __init__(self, ix_apps_pool: str):
        """
        Initialize the ChartVersionRestore class.

        Parameters:
            ix_apps_pool (str): Pool of ix-applications.
        """
        self.logger = get_logger()
        self.ix_apps_pool = ix_apps_pool
        self.logger.debug(f"ChartVersionRestore initialized with pool: {self.ix_apps_pool}")

    @type_check
    def restore_to_chart_dir(self, app_name: str, backup_version_file: Path):
        """
        Restore the chart version to the chart directory.

        Parameters:
            app_name (str): Name of the application.
            backup_version_file (Path): Path to the backup version file.
        """
        self.logger.debug(f"Restoring to chart directory for app: {app_name}")
        target_releases_path = Path(f"/mnt/{self.ix_apps_pool}/ix-applications/releases/{app_name}/charts/{self._strip_tar_gz_extension(backup_version_file)}")
        self.logger.debug(f"Restoring to {target_releases_path}")
        self._restore(backup_version_file, target_releases_path)

    def _restore(self, backup_version_file: Path, target_path: Path):
        """
        Helper method to perform the restoration.

        Parameters:
            backup_version_file (Path): Path to the backup version file.
            target_path (Path): Target path to restore the files to.
        """
        self.logger.debug(f"Restoring from {backup_version_file} to {target_path}")

        if not target_path.exists():
            self.logger.debug(f"Creating target path: {target_path}")
            target_path.mkdir(parents=True, exist_ok=True)

        if not any(target_path.iterdir()):  # Check if directory is empty
            try:
                with tarfile.open(backup_version_file, 'r:gz') as tar:
                    tar.extractall(path=target_path)
                self.logger.debug(f"Extracted {backup_version_file} to {target_path}")
                self.logger.info(f"Restored charts to {target_path}")
            except Exception as e:
                self.logger.error(f"Failed to restore from {backup_version_file} to {target_path}: {e}", exc_info=True)
        else:
            self.logger.debug(f"Skipped restoration, target path {target_path} already exists and is not empty.")

    def _strip_tar_gz_extension(self, file_path: Path) -> str:
        """
        Helper method to strip the .tar.gz extension from a filename.

        Parameters:
            file_path (Path): The file path to strip the extension from.

        Returns:
            str: The filename without the .tar.gz extension.
        """
        name = file_path.name
        if name.endswith('.tar.gz'):
            return name[:-7]
        return name

class ChartVersionUtils:
    """
    Utility class for chart version management.
    """

    @type_check
    def __init__(self, ix_apps_pool: str):
        """
        Initialize the ChartVersionUtils class.

        Parameters:
            ix_apps_pool (str): Pool of ix-applications.
        """
        self.logger = get_logger()
        self.ix_apps_pool = ix_apps_pool
        self.logger.debug(f"ChartVersionUtils initialized with pool: {self.ix_apps_pool}")

    @type_check
    def delete(self, app_name: str, version: str):
        """
        Delete a specific chart version.

        Parameters:
            app_name (str): Name of the application.
            version (str): Version of the chart to delete.
        """
        version_dir = Path(f"/mnt/{self.ix_apps_pool}/ix-applications/releases/{app_name}/charts/{version}")
        self.logger.debug(f"Deleting chart version {version} for app: {app_name} at {version_dir}")
        
        if version_dir.exists() and version_dir.is_dir():
            try:
                shutil.rmtree(version_dir)
                self.logger.debug(f"Cleared contents of {version_dir}")
            except Exception as e:
                self.logger.error(f"Failed to delete {version_dir}: {e}", exc_info=True)
        else:
            self.logger.debug(f"No action taken. {version_dir} does not exist or is not a directory.")

import json
import logging
from pathlib import Path
from utils.singletons import MiddlewareClientManager
from utils.check_job import check_job_status
from utils.type_check import type_check

class CatalogBackupManager:
    """
    Class responsible for managing the backup of catalog data.
    """
    
    @type_check
    def __init__(self, catalog_dir: Path):
        """
        Initialize the CatalogBackupManager class.

        Parameters:
            catalog_dir (Path): The directory where the catalog backup will be stored.
        """
        self.catalog_dir = Path(catalog_dir)
        self.logger = logging.getLogger('BackupLogger')
        self.logger.debug(f"CatalogBackupManager initialized for {self.catalog_dir}")
        self.middleware = MiddlewareClientManager.fetch()

    def backup(self):
        """
        Backup catalog data to a JSON file in the specified directory.
        """
        self.logger.debug("Starting catalog backup process...")
        try:
            catalog_data = self.middleware.call('catalog.query')
            backup_data = json.dumps(catalog_data, indent=4)
            backup_file_path = self.catalog_dir / 'catalog.json'
            self.logger.debug(f"Writing catalog data to {backup_file_path}")
            with open(backup_file_path, 'w') as f:
                f.write(backup_data)
            self.logger.debug(f"Catalog data backed up successfully to {backup_file_path}")
        except Exception as e:
            self.logger.error(f"Failed to backup catalog data: {e}", exc_info=True)

class CatalogRestoreManager:
    """
    Class responsible for managing the restoration of catalog data.
    """

    @type_check
    def __init__(self, catalog_dir: Path):
        """
        Initialize the CatalogRestoreManager class.

        Parameters:
            catalog_dir (Path): The directory where the catalog backup is stored.
        """
        self.catalog_dir = Path(catalog_dir)
        self.logger = logging.getLogger('BackupLogger')
        self.middleware = MiddlewareClientManager.fetch()

    def restore(self):
        """
        Restore catalogs from a JSON file located in the specified directory.
        """
        self.logger.debug("Starting catalog restore process...")
        catalog_file_path = self.catalog_dir / 'catalog.json'

        try:
            with open(catalog_file_path, 'r') as f:
                catalog_data = json.load(f)
            self.logger.debug(f"Catalog data loaded from {catalog_file_path}")
        except Exception as e:
            self.logger.error(f"Failed to load catalog data from {catalog_file_path}: {e}", exc_info=True)
            return

        for entry in catalog_data:
            self._restore_entry(entry)

    def _restore_entry(self, entry):
        """
        Helper function to handle the restoration of a single catalog entry.

        Parameters:
            entry (dict): The catalog entry to restore.
        """
        self.logger.debug(f"Restoring catalog entry: {entry['label']}")
        try:
            existing_catalog = self.middleware.call('catalog.query', [('label', '=', entry['label'])])

            if existing_catalog:
                self.logger.info(f"Catalog {entry['label']} entry already exists.")
            else:
                self.logger.debug(f"Creating catalog entry for {entry['label']}")
                job_id = self.middleware.call('catalog.create', entry)
                if check_job_status(job_id):
                    self.logger.info(f"Catalog {entry['label']} created successfully.")
                else:
                    self.logger.error(f"Failed to create catalog {entry['label']}.")
                    return

            location = Path(entry.get('location', ''))
            if not location.exists():
                self.logger.debug(f"Catalog {entry['label']} location {location} does not exist. Syncing catalog.")
                sync_job_id = self.middleware.call('catalog.sync', entry['label'])
                if check_job_status(sync_job_id):
                    self.logger.info(f"Catalog {entry['label']} synced successfully.")
                else:
                    self.logger.error(f"Failed to sync catalog {entry['label']} due to job error.")
        except Exception as e:
            self.logger.error(f"Failed to restore catalog entry {entry['label']}: {e}", exc_info=True)

class CatalogQueryManager:
    """
    Class responsible for querying catalog data.
    """

    @type_check
    def __init__(self, catalog_dir: Path):
        """
        Initialize the CatalogQueryManager class.

        Parameters:
            catalog_dir (Path): The directory where the catalog backup is stored.
        """
        self.catalog_dir = Path(catalog_dir)
        self.logger = logging.getLogger('BackupLogger')
        self.logger.debug(f"CatalogQueryManager initialized for {self.catalog_dir}")

    def get_catalog_location_by_label(self, label: str) -> str:
        """
        Retrieve the location of a catalog by its label.

        Parameters:
            label (str): The label of the catalog.

        Returns:
            str: The location of the catalog, or None if not found.
        """
        self.logger.debug(f"Getting catalog location for label: {label}")
        catalog_file_path = self.catalog_dir / 'catalog.json'
        try:
            with open(catalog_file_path, 'r') as file:
                catalogs = json.load(file)
                for catalog in catalogs:
                    if catalog['label'] == label:
                        self.logger.debug(f"Location found for label {label}: {catalog['location']}")
                        return catalog['location']
        except Exception as e:
            self.logger.error(f"Error reading catalog file {catalog_file_path}: {e}", exc_info=True)
        self.logger.warning(f"No location found for label {label}")
        return None

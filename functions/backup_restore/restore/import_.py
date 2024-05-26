from pathlib import Path
from utils.type_check import type_check
from utils.logger import setup_global_logger
from catalog.catalog import CatalogRestoreManager
from charts.backup_create import ChartCreationManager

class ChartInfoImporter:
    """
    Class responsible for importing chart information.
    """
    @type_check
    def __init__(self, app_name: str, export_path: Path):
        """
        Initialize the ChartInfoImporter class.

        Parameters:
        - app_name (str): The name of the application to restore.
        - export_path (Path): Path to the exported chart information.
        """
        self.app_name = app_name
        self.export_path = export_path.resolve()
        self.chart_info_dir = self.export_path / "charts" / app_name
        self.catalog_dir = self.export_path / "catalog"

        self.logger = setup_global_logger("import")
        self.logger.info(f"ChartInfoImporter initialized for {app_name}.")

    def import_chart_info(self) -> bool:
        """
        Import chart information and create the application.

        Returns:
            bool: True if the import is successful, False otherwise.
        """
        self.logger.info(f"Starting import process for {self.app_name}...")

        try:
            self._restore_catalog()
            self._create_application()
            self.logger.info(f"Import process completed successfully for {self.app_name}.")
            return True
        except Exception as e:
            self.logger.error(f"Import process failed for {self.app_name}: {e}", exc_info=True)
            return False

    def _restore_catalog(self):
        """Restore the catalog if necessary."""
        self.logger.info("Restoring catalog...")
        try:
            CatalogRestoreManager(self.catalog_dir).restore()
            self.logger.info("Catalog restored successfully.")
        except Exception as e:
            self.logger.warning(f"Failed to restore catalog: {e}")

    def _create_application(self):
        """Create the application based on the metadata and values JSON files."""
        self.logger.info(f"Creating application for {self.app_name}...")
        metadata_file = self.chart_info_dir / "metadata.json"
        values_file = self.chart_info_dir / "values.json"

        if not metadata_file.exists() or not values_file.exists():
            raise FileNotFoundError(f"Metadata or values file is missing for {self.app_name}.")

        creation_manager = ChartCreationManager()
        result = creation_manager.create(metadata_file, values_file)
        if result['success']:
            self.logger.info(f"Application {self.app_name} created successfully.")
        else:
            self.logger.error(f"Failed to create application {self.app_name}: {result['message']}")
            raise RuntimeError(f"Failed to create application {self.app_name}. Error: {result['message']}")

import json
import shutil
import yaml
from datetime import datetime, timezone
from pathlib import Path

from utils.logger import setup_global_logger, set_logger
from utils.type_check import type_check
from catalog.catalog import CatalogBackupManager
from charts.backup_create import ChartBackupManager
from charts.api_fetch import APIChartFetcher, APIChartCollection

class ChartInfoExporter:
    """
    Class responsible for exporting chart information.
    """
    @type_check
    def __init__(self, export_dir: Path, retention_number: int = 15):
        """
        Initialize the ChartInfoExporter class.

        Parameters:
        - export_dir (Path): Directory to export the chart information.
        - retention_number (int): Number of exports to retain. Defaults to 15.
        """
        logger = setup_global_logger("export")
        set_logger(logger)
        self.logger = logger
        self.logger.info("Initializing ChartInfoExporter...")
        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d_%H:%M:%S')

        self.export_dir = export_dir.resolve()
        self.retention_number = retention_number
        self.export_root = self.export_dir / f"Export--{timestamp}"
        self.export_root.mkdir(parents=True, exist_ok=True)

        self.chart_collection = APIChartCollection()
        self.all_release_names = self.chart_collection.all_release_names
        self.logger.info("ChartInfoExporter initialized.")

    def export(self):
        """
        Export chart information for all applications.
        """
        self.logger.info(f"Exporting chart information to: {self.export_root}")
        
        catalog_dir = self.export_root / "catalog"
        catalog_dir.mkdir(parents=True, exist_ok=True)
        CatalogBackupManager(catalog_dir).backup()

        for app_name in self.all_release_names:
            self.logger.info(f"Exporting chart info for {app_name}...")
            app_export_dir = self.export_root / "charts" / app_name
            app_export_dir.mkdir(parents=True, exist_ok=True)

            chart_info = APIChartFetcher(app_name)
            if not chart_info.is_valid:
                self.logger.error(f"Failed to fetch chart data for {app_name}")
                continue

            chart_info_dir = app_export_dir 
            chart_info_dir.mkdir(parents=True, exist_ok=True)
            backup_chart = ChartBackupManager(chart_info_dir)
            backup_chart.backup_metadata(app_name, chart_info.chart_name, chart_info.catalog, chart_info.train, chart_info.version)
            backup_chart.backup_values(app_name, chart_info.chart_config, clean=True)
            self._convert_json_to_yaml(chart_info_dir / 'values.json')
        
        self.logger.info("Chart information export completed.")
        self._cleanup_old_exports()

    def _cleanup_old_exports(self):
        """
        Cleanup old exports if the number of exports exceeds the retention limit.
        """
        export_dirs = sorted(
            (d for d in self.export_dir.iterdir() if d.is_dir() and d.name.startswith("Export--")),
            key=lambda d: datetime.strptime(d.name.replace("Export--", ""), '%Y-%m-%d_%H:%M:%S')
        )

        if len(export_dirs) > self.retention_number:
            for old_export_dir in export_dirs[:-self.retention_number]:
                self.logger.info(f"Deleting oldest export due to retention limit: {old_export_dir.name}")
                try:
                    shutil.rmtree(old_export_dir)
                    self.logger.debug(f"Removed old export: {old_export_dir}")
                except Exception as e:
                    self.logger.error(f"Failed to delete old export directory {old_export_dir}: {e}", exc_info=True)

    def _convert_json_to_yaml(self, json_file: Path):
        """
        Convert a JSON file to YAML format and save it.

        Parameters:
        - json_file (Path): The path to the JSON file.
        """
        try:
            if json_file.exists():
                with open(json_file, 'r') as file:
                    data = json.load(file)
                yaml_file = json_file.with_suffix('.yaml')
                with open(yaml_file, 'w') as file:
                    yaml.dump(data, file)
                self.logger.debug(f"Converted {json_file} to {yaml_file}")
        except Exception as e:
            self.logger.error(f"Failed to convert {json_file} to YAML: {e}", exc_info=True)

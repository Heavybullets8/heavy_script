import json
import logging
from pathlib import Path
from utils.singletons import MiddlewareClientManager
from middlewared.client import ClientException
from utils.type_check import type_check
from typing import Dict

class ChartBackupManager:
    """
    Class responsible for managing the backup of chart metadata and values.
    """
    
    @type_check
    def __init__(self, backup_dir: Path):
        """
        Initialize the ChartBackupManager class.

        Parameters:
            backup_dir (Path): The directory where backups will be stored.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.backup_dir = backup_dir
        self.logger.debug(f"ChartBackupManager initialized for backup directory: {self.backup_dir}")

    @type_check
    def backup_metadata(self, app_name: str, chart_name: str, catalog: str, train: str, version: str) -> bool:
        """
        Backup metadata for a specific application.

        Parameters:
            app_name (str): The name of the application.
            chart_name (str): The name of the chart.
            catalog (str): The catalog of the chart.
            train (str): The train of the chart.
            version (str): The version of the chart.

        Returns:
            bool: True if successful, False otherwise.
        """
        self.logger.debug(f"Backing up metadata for app: {app_name}")
        try:
            metadata = {
                "chart_name": chart_name,
                "catalog": catalog,
                "train": train,
                "version": version,
                "release_name": app_name
            }
            metadata_file = self.backup_dir / 'metadata.json'
            self.logger.debug(f"Writing metadata to {metadata_file}")
            with open(metadata_file, 'w') as file:
                json.dump(metadata, file, indent=4)
            self.logger.debug(f"Metadata backed up successfully for {app_name}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to backup metadata for {app_name}: {e}", exc_info=True)
            return False

    @type_check
    def backup_values(self, app_name: str, config: Dict, clean: bool = False) -> bool:
        """
        Backup configuration values for a specific application.

        Parameters:
            app_name (str): The name of the application.
            config (Dict): The configuration values to backup.
            clean (bool): If True, remove ix keys from the configuration.

        Returns:
            bool: True if successful, False otherwise.
        """
        self.logger.debug(f"Backing up values for app: {app_name}")
        try:
            if clean:
                config = self._clean_config(config)
            config_file = self.backup_dir / 'values.json'
            self.logger.debug(f"Writing configuration values to {config_file}")
            with open(config_file, 'w') as file:
                json.dump(config, file, indent=4)
            self.logger.debug(f"Values backed up successfully for {app_name}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to backup values for {app_name}: {e}", exc_info=True)
            return False

    @type_check
    def _clean_config(self, config: Dict) -> Dict:
        """
        Clean the configuration values by removing ix keys.

        Parameters:
            config (Dict): The configuration values to clean.

        Returns:
            Dict: The cleaned configuration values.
        """
        keys_to_remove = [
            'ixCertificateAuthorities',
            'ixCertificates',
            'ixChartContext',
            'ixExternalInterfacesConfiguration',
            'ixExternalInterfacesConfigurationNames',
            'ixVolumes'
        ]

        def recursive_remove_keys(d):
            if not isinstance(d, dict):
                return d
            return {k: recursive_remove_keys(v) for k, v in d.items() if k not in keys_to_remove}

        return recursive_remove_keys(config)

class ChartCreationManager:
    """
    Class responsible for managing the creation of chart releases.
    """

    def __init__(self):
        """
        Initialize the ChartCreationManager class.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.middleware = MiddlewareClientManager.fetch()
        self.logger.debug("ChartCreationManager initialized.")

    @type_check
    def create(self, metadata_file: Path, values_file: Path) -> dict:
        """
        Create a chart release for a specific application.

        Parameters:
            metadata_file (Path): The path to the metadata file.
            values_file (Path): The path to the values file.

        Returns:
            dict: Result containing status and message.
        """
        self.logger.debug(f"Creating chart release for {metadata_file} and {values_file}")
        result = {
            "success": False,
            "message": "",
            "retry": False
        }

        def create_chart_release(data):
            return self.middleware.call('chart.release.create', data, job=True)

        try:
            self.logger.debug(f"Reading metadata from {metadata_file}")
            with open(metadata_file, 'r') as meta_file:
                metadata = json.load(meta_file)
            self.logger.debug(f"Metadata loaded: {metadata}")

            self.logger.debug(f"Reading values from {values_file}")
            with open(values_file, 'r') as values_file:
                values = json.load(values_file)
            self.logger.debug(f"Values loaded: {values}")

            values = self._stop_values_false(values)

            data = {
                "values": values,
                "catalog": metadata['catalog'],
                "item": metadata['chart_name'],
                "release_name": metadata['release_name'],
                "train": metadata['train'],
                "version": metadata['version']
            }

            self.logger.debug(f"Data prepared for chart release: {data}")

            try:
                create_chart_release(data)
                result["success"] = True
                result["message"] = f"Chart release created successfully for {metadata['release_name']}"
            except ClientException as e:
                if '[ENOENT] Unable to locate' in str(e):
                    self.logger.warning(f"Specific version not found, retrying without version: {e}")
                    del data['version']
                    create_chart_release(data)
                    result["success"] = True
                    result["message"] = f"Chart release created successfully for {metadata['release_name']} without specific version"
                else:
                    raise e
        except ClientException as e:
            if '[EFAULT] Unable delete namespace' in str(e):
                self.logger.warning(f"Namespace deletion error encountered, retrying: {e}")
                try:
                    create_chart_release(data)
                    result["success"] = True
                    result["message"] = f"Chart release created successfully for {metadata['release_name']} after retry"
                except Exception as retry_exception:
                    self.logger.error(f"Retry failed: {retry_exception}", exc_info=True)
                    result["message"] = str(retry_exception)
            else:
                self._handle_creation_error(e, metadata, result)
        except Exception as e:
            self._handle_creation_error(e, metadata, result)

        return result

    def _stop_values_false(self, config: Dict) -> Dict:
        """
        Ensure specific keys have the desired values.

        Parameters:
            config (Dict): The configuration values.

        Returns:
            Dict: The configuration values with specific keys set.
        """
        if 'global' not in config:
            config['global'] = {}

        if 'ixChartContext' not in config['global']:
            config['global']['ixChartContext'] = {}

        config['global']['ixChartContext']['isStopped'] = False
        config['global']['stopAll'] = False

        return config

    def _handle_creation_error(self, error, metadata, result):
        self.logger.error(f"Failed to create chart release: {error}", exc_info=True)
        if metadata and 'release_name' in metadata:
            self.logger.error(f"Error details for release {metadata['release_name']}")
        result["message"] = str(error)
        result["retry"] = '[ENOENT] Unable to locate' in str(error)
import json
from pathlib import Path
from typing import Dict, List, Union
from utils.logger import get_logger
from utils.type_check import type_check

class BackupChartFetcher:
    """
    Class responsible for fetching and parsing backup chart data.
    """
    
    @type_check
    def __init__(self, charts_base_dir: Path):
        """
        Initialize the BackupChartFetcher class.

        Parameters:
            charts_base_dir (Path): The base directory containing chart data.
        """
        self.logger = get_logger()
        self.charts_base_dir = charts_base_dir
        self.charts_info: Dict[str, Dict[str, Union[str, Path, dict]]] = {}
        self._parse_all_charts()

    def _parse_all_charts(self) -> None:
        """
        Parse metadata and config for all charts and store in memory.
        """
        for chart_dir in self.charts_base_dir.iterdir():
            if chart_dir.is_dir():
                app_name = chart_dir.stem
                chart_info = self._parse_chart(chart_dir, app_name)
                if chart_info:
                    self.charts_info[app_name] = chart_info

        # Print the entire charts_info dictionary to the debug log
        self.logger.debug("Completed parsing all charts. Final charts_info state:")
        self.logger.debug(json.dumps(self._serialize_charts_info(), indent=4, default=str))

    def _parse_chart(self, chart_base_dir: Path, app_name: str) -> Dict[str, Union[str, Path, dict]]:
        """
        Parse metadata and config for a single chart and return structured information.

        Parameters:
            chart_base_dir (Path): The base directory of the chart.
            app_name (str): The name of the application.

        Returns:
            dict: A dictionary containing the parsed chart information.
        """
        chart_info = {
            'metadata': {
                'chart_name': '',
                'version': '',
                'train': '',
                'catalog': '',
                'dataset': '',
                'is_cnpg': False,
            },
            'config': {
                'ixVolumes': []
            },
            'files': {
                'database': None,
                'namespace': None,
                'metadata': None,
                'values': None,
                'chart_version': None,
                'secrets': [],
                'crds': [],
                'pv_zfs_volumes': [],
                'snapshots': []
            }
        }

        chart_info_dir = chart_base_dir / 'chart_info'
        kubernetes_objects_dir = chart_base_dir / 'kubernetes_objects'
        database_dir = chart_base_dir / 'database'
        versions_dir = chart_base_dir / 'chart_versions'
        snapshots_dir = chart_base_dir / 'snapshots'

        # Parse metadata and config
        metadata = self._parse_metadata(chart_info_dir)
        config = self._parse_config(chart_info_dir)

        if metadata and config:
            chart_info['metadata']['chart_name'] = metadata.get('chart_name', '')
            chart_info['metadata']['version'] = metadata.get('version', '')
            chart_info['metadata']['train'] = metadata.get('train', '')
            chart_info['metadata']['catalog'] = metadata.get('catalog', '')
            chart_info['metadata']['dataset'] = metadata.get('dataset', '')
            chart_info['metadata']['is_cnpg'] = self._is_cnpg(config)

            chart_info['config']['ixVolumes'] = config.get('ixVolumes', [])

            # Add files
            chart_info['files']['database'] = self._get_database_file(database_dir, app_name)
            chart_info['files']['namespace'] = self._get_file(kubernetes_objects_dir / 'namespace' / 'namespace.yaml')
            chart_info['files']['metadata'] = self._get_file(chart_info_dir / 'metadata.json')
            chart_info['files']['values'] = self._get_file(chart_info_dir / 'values.json')
            chart_info['files']['chart_version'] = self._get_chart_version_file(versions_dir)
            chart_info['files']['secrets'] = self._get_files(kubernetes_objects_dir / 'secrets')
            chart_info['files']['crds'] = self._get_files(kubernetes_objects_dir / 'crds')
            chart_info['files']['pv_zfs_volumes'] = self._get_files(kubernetes_objects_dir / 'pv_zfs_volumes')
            chart_info['files']['cnpg_pvcs_to_delete'] = self._get_file(kubernetes_objects_dir / 'cnpg_pvcs_to_delete.txt')
            chart_info['files']['snapshots'] = self._get_files(snapshots_dir)

            return chart_info

        return {}

    def _parse_metadata(self, chart_info_dir: Path) -> dict:
        """
        Parse metadata from the metadata.json file.

        Parameters:
            chart_info_dir (Path): The directory containing metadata.json.

        Returns:
            dict: Parsed metadata.
        """
        return self._parse_json_file(chart_info_dir / 'metadata.json')

    def _parse_config(self, chart_info_dir: Path) -> dict:
        """
        Parse configuration from the values.json file.

        Parameters:
            chart_info_dir (Path): The directory containing values.json.

        Returns:
            dict: Parsed configuration.
        """
        return self._parse_json_file(chart_info_dir / 'values.json')

    def _parse_json_file(self, file_path: Path) -> dict:
        """
        Parse JSON data from a file.

        Parameters:
            file_path (Path): The path to the JSON file.

        Returns:
            dict: Parsed JSON data.
        """
        self.logger.debug(f"Parsing JSON from file: {file_path}")
        if file_path.exists():
            try:
                with open(file_path, 'r') as file:
                    data = json.load(file)
                    self.logger.debug(f"Successfully parsed JSON from file: {file_path}")
                    return data
            except (json.JSONDecodeError, IOError) as e:
                self.logger.error(f"Error reading JSON from {file_path}: {e}", exc_info=True)
        else:
            self.logger.error(f"File does not exist: {file_path}")
        return {}

    def _is_cnpg(self, config: dict) -> bool:
        """
        Check if the release is a CNPG application from config.

        Parameters:
            config (dict): The configuration dictionary.

        Returns:
            bool: True if the release is a CNPG application, False otherwise.
        """
        cnpg_config = config.get('cnpg', {})
        return any(subconfig.get('enabled', False) for subconfig in cnpg_config.values() if isinstance(subconfig, dict))

    def _get_file(self, file_path: Path) -> Union[Path, None]:
        """
        Return the file path if it exists, else return None.

        Parameters:
            file_path (Path): The path to the file.

        Returns:
            Union[Path, None]: The file path or None.
        """
        return file_path.resolve() if file_path.exists() else None

    def _get_files(self, dir_path: Path) -> List[Path]:
        """
        Return a list of files in the directory if it exists, else return an empty list.

        Parameters:
            dir_path (Path): The path to the directory.

        Returns:
            List[Path]: A list of file paths.
        """
        if dir_path.exists():
            return [file.resolve() for file in dir_path.iterdir() if file.is_file()]
        return []

    def _get_database_file(self, database_dir: Path, release_name: str) -> Union[Path, None]:
        """
        Return the database file path if it exists, else return None.

        Parameters:
            database_dir (Path): The path to the database directory.
            release_name (str): The name of the release.

        Returns:
            Union[Path, None]: The database file path or None.
        """
        sql_file = database_dir / f'{release_name}.sql'
        sql_gz_file = database_dir / f'{release_name}.sql.gz'
        if sql_file.exists():
            return sql_file.resolve()
        if sql_gz_file.exists():
            return sql_gz_file.resolve()
        return None

    def _get_chart_version_file(self, versions_dir: Path) -> Union[Path, None]:
        """
        Return the chart version file if it exists, else return None.

        Parameters:
            versions_dir (Path): The path to the chart versions directory.

        Returns:
            Union[Path, None]: The chart version file path or None.
        """
        for file in versions_dir.iterdir():
            if file.suffix == '.gz':
                return file.resolve()
        return None

    @property
    def cnpg_apps(self) -> List[str]:
        """
        Return a list of CNPG applications.

        Returns:
            List[str]: A list of CNPG application names.
        """
        return [app for app, info in self.charts_info.items() if info['metadata']['is_cnpg']]

    @property
    def chart_names(self) -> List[str]:
        """
        Return a list of chart names.

        Returns:
            List[str]: A list of chart names.
        """
        return [info['metadata']['chart_name'] for info in self.charts_info.values()]

    @property
    def apps_with_crds(self) -> List[str]:
        """
        Return a list of applications with CRDs.

        Returns:
            List[str]: A list of application names with CRDs.
        """
        return [app for app, info in self.charts_info.items() if info['files']['crds']]

    @property
    def all_releases(self) -> List[str]:
        """
        Return all release names sorted with custom logic.

        Returns:
            List[str]: A sorted list of release names.
        """
        priority_list = ["prometheus-operator", "openebs", "cloudnative-pg", "cert-manager", "metallb", "traefik"]

        def sort_key(app_name):
            chart_name = self.get_chart_name(app_name)
            if chart_name in priority_list:
                return (0, priority_list.index(chart_name))
            if app_name in self.cnpg_apps:
                return (2, app_name)
            return (1, app_name)

        return sorted(self.charts_info.keys(), key=sort_key)

    def get_file(self, app_name: str, file_type: str) -> Union[Path, None, List[Path]]:
        """
        Get the specific file or files for a given release name.

        Parameters:
            app_name (str): The name of the application.
            file_type (str): The type of file to retrieve.

        Returns:
            Union[Path, None, List[Path]]: The file path, list of file paths, or None.
        """
        return self.charts_info.get(app_name, {}).get('files', {}).get(file_type)

    def get_chart_name(self, app_name: str) -> str:
        """
        Get the chart name for a given release name.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            str: The chart name.
        """
        return self.charts_info.get(app_name, {}).get('metadata', {}).get('chart_name', '')

    def get_version(self, app_name: str) -> str:
        """
        Get the version for a given release name.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            str: The version.
        """
        return self.charts_info.get(app_name, {}).get('metadata', {}).get('version', '')

    def get_catalog(self, app_name: str) -> str:
        """
        Get the catalog for a given release name.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            str: The catalog.
        """
        return self.charts_info.get(app_name, {}).get('metadata', {}).get('catalog', '')

    def get_train(self, app_name: str) -> str:
        """
        Get the train for a given release name.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            str: The train.
        """
        return self.charts_info.get(app_name, {}).get('metadata', {}).get('train', '')

    def get_release_name(self, chart_name: str) -> str:
        """
        Get the release name for a given chart name.

        Parameters:
            chart_name (str): The name of the chart.

        Returns:
            str: The release name.
        """
        for app_name, info in self.charts_info.items():
            if info['metadata']['chart_name'] == chart_name:
                return app_name
        return ''

    def get_dataset(self, app_name: str) -> str:
        """
        Get the dataset for a given release name.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            str: The dataset.
        """
        return self.charts_info.get(app_name, {}).get('metadata', {}).get('dataset', '')

    @type_check
    def get_ix_volumes_dataset(self, app_name: str) -> Union[str, None]:
        """
        Get the ixVolumes dataset path for a given application.

        Returns:
        - str: The ixVolumes dataset path if it exists, else None.
        """
        ix_volumes = self.charts_info.get(app_name, {}).get("config", {}).get("ixVolumes", [])
        if ix_volumes:
            host_path = ix_volumes[0].get("hostPath")
            if host_path:
                # Remove the "/mnt/" prefix
                if host_path.startswith("/mnt/"):
                    host_path = host_path[5:]
                # Remove the last directory to get the dataset path
                dataset_path = str(Path(host_path).parent)
                return dataset_path
        return None

    def handle_critical_failure(self, app_name: str) -> None:
        """
        Remove the application from all_releases and other relevant lists.

        Parameters:
            app_name (str): The name of the application.
        """
        if app_name in self.charts_info:
            del self.charts_info[app_name]

        # Remove app from computed properties
        for lst in [self.all_releases, self.cnpg_apps, self.chart_names, self.apps_with_crds]:
            try:
                lst.remove(app_name)
            except ValueError:
                pass

    def _serialize_charts_info(self) -> dict:
        """
        Helper method to serialize charts_info for logging.

        Returns:
            dict: Serialized charts_info data.
        """
        return {
            app: {
                'metadata': info['metadata'],
                'files': {
                    k: str(v) if isinstance(v, Path) else (
                        [str(i) for i in v] if v is not None else 'None'
                    ) for k, v in info['files'].items()
                }
            } for app, info in self.charts_info.items()
        }

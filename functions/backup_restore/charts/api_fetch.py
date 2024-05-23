import logging
import threading
from abc import ABC, abstractmethod
from typing import Dict, List
from utils.type_check import type_check
from utils.singletons import MiddlewareClientManager

class ChartObserver(ABC):
    @abstractmethod
    def update(self, force_refresh: bool = True):
        """
        Method to be implemented by subclasses to handle updates from ChartCache.

        Parameters:
            force_refresh (bool): Flag indicating if the refresh should be forced.
        """
        pass

class APIChartFetcher(ChartObserver):
    @type_check
    def __init__(self, app_name: str, refresh_on_update: bool = True):
        """
        Initialize the APIChartFetcher class.

        Parameters:
            app_name (str): The name of the application.
            refresh_on_update (bool): Flag to control if updates should trigger a refresh.
        """
        self.app_name = app_name
        self.logger = logging.getLogger('BackupLogger')
        self.chart_cache = ChartCache()
        self.chart_cache.add_observer(self)
        self.refresh_on_update = refresh_on_update
        self._chart_data = self.chart_cache.get_chart(self.app_name)
        self.logger.debug(f"Initializing APIChartFetcher for app: {self.app_name}")

    @type_check
    def update(self, force_refresh: bool = True):
        """
        Update the chart data when notified by ChartCache.

        Parameters:
            force_refresh (bool): Flag indicating if the refresh should be forced.
        """
        if self.refresh_on_update and force_refresh:
            self._chart_data = self.chart_cache.get_chart(self.app_name)
            self.logger.debug(f"ChartCache updated for app: {self.app_name}")

    @type_check
    def refresh(self):
        """
        Manually refresh the chart data by forcing ChartCache to update.
        """
        self.logger.debug("Refreshing all chart data in ChartCache.")
        self.chart_cache.refresh()

    @property
    def chart(self) -> Dict[str, dict]:
        """
        Return the latest chart data for the current application.

        Returns:
            Dict[str, dict]: The chart data for the application.
        """
        return self._chart_data

    @property
    def chart_name(self) -> str:
        """
        Return the chart name for the current application.

        Returns:
            str: The name of the chart.
        """
        chart_name = self.chart.get('chart_metadata', {}).get('name', '') if self.chart else ""
        self.logger.debug(f"Chart name for app {self.app_name}: {chart_name}")
        return chart_name

    @property
    def catalog(self) -> str:
        """
        Return the catalog for the current application.

        Returns:
            str: The catalog of the chart.
        """
        catalog = self.chart.get('catalog', '') if self.chart else ""
        self.logger.debug(f"Catalog for app {self.app_name}: {catalog}")
        return catalog

    @property
    def train(self) -> str:
        """
        Return the train for the current application.

        Returns:
            str: The train of the chart.
        """
        train = self.chart.get('catalog_train', '') if self.chart else ""
        self.logger.debug(f"Train for app {self.app_name}: {train}")
        return train

    @property
    def version(self) -> str:
        """
        Return the version for the current application.

        Returns:
            str: The version of the chart.
        """
        version = self.chart.get('chart_metadata', {}).get('version', '') if self.chart else ""
        self.logger.debug(f"Version for app {self.app_name}: {version}")
        return version

    @property
    def status(self) -> str:
        """
        Return the status for the current application.

        Returns:
            str: The status of the chart.
        """
        status = self.chart.get('status', '') if self.chart else ""
        self.logger.debug(f"Status for app {self.app_name}: {status}")
        return status

    @property
    def stop_all(self) -> bool:
        """
        Return if stopAll is enabled in the chart config.

        Returns:
            bool: True if stopping is allowed, False otherwise.
        """
        stop_all = self.chart.get('config', {}).get('global', {}).get('stopAll', False)
        self.logger.debug(f"Stop all for app {self.app_name}: {stop_all}")
        return stop_all

    @property
    def is_stopped(self) -> bool:
        """
        Return if isStopped is enabled in the chart config.

        Returns:
            bool: True if the application is stopped, False otherwise.
        """
        is_stopped = self.chart.get('config', {}).get('global', {}).get('ixChartContext', {}).get('isStopped', False)
        self.logger.debug(f"Is stopped for app {self.app_name}: {is_stopped}")
        return is_stopped

    @property
    def is_valid(self) -> bool:
        """
        Return if the application is valid.

        Returns:
            bool: True if the application is valid, False otherwise.
        """
        is_valid = bool(self.chart) and isinstance(self.chart, dict) and 'chart_metadata' in self.chart
        self.logger.debug(f"Is valid for app {self.app_name}: {is_valid}")
        return is_valid
    
    @property
    def primary_cnpg_pod(self) -> str:
        """
        Return the name of the primary CNPG pod if it exists.

        Returns:
            str: The name of the primary CNPG pod, or an empty string if not applicable.
        """
        if not self.is_cnpg:
            self.logger.debug(f"App {self.app_name} is not a CNPG application.")
            return ""
        
        primary_pod = ""
        pods = self.chart.get('resources', {}).get('pods', [])
        for pod in pods:
            labels = pod.get('metadata', {}).get('labels', {})
            if labels.get('cnpg.io/instanceRole') == 'primary':
                primary_pod = pod.get('metadata', {}).get('name', '')
                break
        self.logger.debug(f"Primary CNPG pod for app {self.app_name}: {primary_pod}")
        return primary_pod

    @property
    def chart_config(self) -> dict:
        """
        Return the config for the current application.

        Returns:
            dict: The configuration of the chart.
        """
        chart_config = self.chart.get('config', {}) if self.chart else {}
        self.logger.debug(f"Chart config for app {self.app_name}: {chart_config}")
        return chart_config

    @property
    def is_cnpg(self) -> bool:
        """
        Check if the release is a CNPG application based on config.

        Returns:
            bool: True if the application is a CNPG application, False otherwise.
        """
        cnpg_config = self.chart_config.get('cnpg', {})
        is_cnpg = any(subconfig.get('enabled', False) for subconfig in cnpg_config.values() if isinstance(subconfig, dict))
        self.logger.debug(f"Is CNPG for app {self.app_name}: {is_cnpg}")
        return is_cnpg

    @property
    def has_pvc(self) -> bool:
        """
        Check if the release has PVCs based on config.

        Returns:
            bool: True if the application has PVCs, False otherwise.
        """
        persistence = self.chart_config.get('persistence', {})
        has_pvc = any(value.get('type') == 'pvc' for value in persistence.values() if isinstance(value, dict))
        self.logger.debug(f"Has PVCs for app {self.app_name}: {has_pvc}")
        return has_pvc

class APIChartCollection(ChartObserver):
    @type_check
    def __init__(self, refresh_on_update: bool = True):
        """
        Initialize the APIChartCollection class.

        Parameters:
            refresh_on_update (bool): Flag to control if updates should trigger a refresh.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.chart_cache = ChartCache()
        self.chart_cache.add_observer(self)
        self.refresh_on_update = refresh_on_update
        self._charts_data = self.chart_cache.get_all_charts()
        self.logger.debug("Initializing APIChartCollection")

    @type_check
    def update(self, force_refresh: bool = True):
        """
        Update the chart data when notified by ChartCache.

        Parameters:
            force_refresh (bool): Flag indicating if the refresh should be forced.
        """
        if self.refresh_on_update and force_refresh:
            self._charts_data = self.chart_cache.get_all_charts()
            self._log_charts_truncated()
            self.logger.debug("ChartCache updated in APIChartCollection")

    def _log_charts_truncated(self):
        """
        Log truncated chart data for debugging purposes.
        """
        truncated_charts = []
        for chart in self.charts:
            truncated_chart = {k: (str(v)[:100] + '...') if len(str(v)) > 100 else v for k, v in chart.items()}
            truncated_charts.append(truncated_chart)
        self.logger.debug(f"All charts fetched (truncated): {truncated_charts}")

    def refresh(self):
        """
        Manually refresh the chart data by forcing ChartCache to update.
        """
        self.logger.debug("Refreshing all chart data in ChartCache.")
        self.chart_cache.refresh()

    @property
    def charts(self) -> List[dict]:
        """
        Return the latest chart data.

        Returns:
            List[dict]: A list of all chart data.
        """
        return self._charts_data

    @property
    def all_chart_names(self) -> List[str]:
        """
        Return a sorted list of all chart names.

        Returns:
            List[str]: A list of all chart names.
        """
        chart_names = sorted([chart.get('chart_metadata', {}).get('name', '') for chart in self.charts if 'chart_metadata' in chart])
        self.logger.debug(f"All chart names: {chart_names}")
        return chart_names

    @property
    def all_release_names(self) -> List[str]:
        """
        Return a sorted list of all release names.

        Returns:
            List[str]: A list of all release names.
        """
        release_names = sorted([chart['name'] for chart in self.charts if 'name' in chart])
        self.logger.debug(f"All release names: {release_names}")
        return release_names

    @property
    def all_apps_with_pvcs(self) -> List[str]:
        """
        Return a list of all applications with PVCs.

        Returns:
            List[str]: A list of applications that have PVCs.
        """
        apps_with_pvcs = []
        for chart in self.charts:
            persistence = chart.get('config', {}).get('persistence', {})
            if any(value.get('type') == 'pvc' for value in persistence.values() if isinstance(value, dict)):
                apps_with_pvcs.append(chart['name'])
        self.logger.debug(f"All applications with PVCs: {apps_with_pvcs}")
        return apps_with_pvcs

    @property
    def all_cnpg_apps(self) -> List[str]:
        """
        Return a list of all CNPG applications.

        Returns:
            List[str]: A list of CNPG applications.
        """
        cnpg_apps = [chart['name'] for chart in self.charts if 'config' in chart and 'cnpg' in chart['config']]
        self.logger.debug(f"All CNPG applications: {cnpg_apps}")
        return cnpg_apps
    
class ChartCache:
    """
    Singleton class to manage the chart data cache.
    This class ensures that the chart data is fetched and cached centrally.
    """
    _instance = None
    _lock = threading.Lock()
    _observers = []

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super(ChartCache, cls).__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        """
        Initialize the ChartCache class. Fetch all charts if not already initialized.
        """
        if not self._initialized:
            self.logger = logging.getLogger('BackupLogger')
            self.middleware = MiddlewareClientManager.fetch()
            self._charts = self._fetch_all_charts()
            self._initialized = True
            self.logger.debug("ChartCache initialized.")

    @type_check
    def _fetch_all_charts(self) -> Dict[str, dict]:
        """
        Fetch all charts from the middleware and cache them.

        Returns:
            Dict[str, dict]: A dictionary of all charts and their resources.
        """
        try:
            charts = self.middleware.call('chart.release.query', [], {'extra': {'retrieve_resources': True}})
            if charts:
                self.logger.debug("All chart data fetched successfully.")
                return {chart['id']: chart for chart in charts}
            else:
                self.logger.warning("No chart data found.")
        except Exception as e:
            self.logger.error(f"Failed to fetch all chart data: {e}", exc_info=True)
        return {}

    @type_check
    def refresh(self) -> None:
        """
        Perform a refresh by fetching new data from the middleware.
        """
        with self._lock:
            self._charts = self._fetch_all_charts()
            self._notify_observers()
        self.logger.debug("Chart cache refreshed.")

    def _notify_observers(self):
        """
        Notify all registered observers of a data update.
        """
        for observer in self._observers:
            observer.update()

    @property
    def charts(self) -> Dict[str, dict]:
        """
        Return the cached chart data.

        Returns:
            Dict[str, dict]: A dictionary of all charts and their resources.
        """
        with self._lock:
            return self._charts

    @type_check
    def get_chart(self, app_name: str) -> dict:
        """
        Retrieve a specific chart from the cached data.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            dict: The chart data for the specified application.
        """
        self.logger.debug(f"Retrieving chart data for application: {app_name}")
        with self._lock:
            return self._charts.get(app_name, None)

    def get_all_charts(self) -> List[dict]:
        """
        Return a list of all cached charts.

        Returns:
            List[dict]: A list of all chart data.
        """
        self.logger.debug("Retrieving all chart data.")
        with self._lock:
            return list(self._charts.values())

    @type_check
    def add_observer(self, observer: ChartObserver):
        """
        Add an observer to the notification list.

        Parameters:
            observer (ChartObserver): The observer to add.
        """
        self._observers.append(observer)
    
    @type_check
    def remove_observer(self, observer: ChartObserver):
        """
        Remove an observer from the notification list.

        Parameters:
            observer (ChartObserver): The observer to remove.
        """
        self._observers.remove(observer)
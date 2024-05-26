import threading
from abc import ABC, abstractmethod
from typing import Dict, List
from utils.logger import get_logger
from utils.type_check import type_check
from utils.singletons import MiddlewareClientManager

class ChartObserver(ABC):
    @abstractmethod
    def update(self):
        """
        Method to be implemented by subclasses to handle updates from ChartCache.
        """
        pass

class APIChartFetcher(ChartObserver):
    @type_check
    def __init__(self, app_name: str, refresh_on_update: bool = False):
        """
        Initialize the APIChartFetcher class.

        Parameters:
            app_name (str): The name of the application.
            refresh_on_update (bool): Flag to control if updates should trigger a refresh.
        """
        self.app_name = app_name
        self.logger = get_logger()
        self.chart_cache = ChartCache()
        self.status_callback = None
        self.refresh_on_update = refresh_on_update
        self._chart_data = self.chart_cache.get_chart(self.app_name)
        self.logger.debug(f"Initializing APIChartFetcher for app: {self.app_name}")

        # If the chart data is not valid, trigger a refresh
        # Needed as sometimes the ChartCache does not yet contain the data for the requested app
        if not self.is_valid:
            self.logger.debug(f"Chart data for {self.app_name} is not valid. Triggering refresh.")
            self.refresh()

        if self.refresh_on_update:
            self.chart_cache.add_observer(self)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def register_status_callback(self, callback):
        """
        Register a callback to be called when the status changes.

        Parameters:
            callback (function): The callback function to register.
        """
        self.status_callback = callback

    def update(self):
        """
        Update the chart data when notified by ChartCache.
        """
        self.logger.debug(f"Updating chart data for app: {self.app_name}")
        self._chart_data = self.chart_cache.get_chart(self.app_name)
        if self.status_callback:
            self.status_callback()

    def refresh(self):
        """
        Manually refresh the chart data.
        """
        self.logger.debug(f"Manual refresh requested for app: {self.app_name}")
        self.chart_cache.queue_refresh(self._update_chart_data)

    def _update_chart_data(self):
        """
        Update chart data from ChartCache.
        """
        self._chart_data = self.chart_cache.get_chart(self.app_name)
        self.logger.debug(f"Chart data refreshed for app: {self.app_name}")
        if self.status_callback:
            self.status_callback()

    def close(self):
        """
        Remove this instance from the observer list in ChartCache, if it was added.
        """
        if self.refresh_on_update:
            self.logger.debug(f"Closing APIChartFetcher for app {self.app_name}")
            self.chart_cache.remove_observer(self)

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
    def __init__(self, refresh_on_update: bool = False):
        """
        Initialize the APIChartCollection class.

        Parameters:
            refresh_on_update (bool): Flag to control if updates should trigger a refresh.
        """
        self.logger = get_logger()
        self.chart_cache = ChartCache()
        self.refresh_on_update = refresh_on_update
        self._charts_data = self.chart_cache.get_all_charts()
        self.logger.debug("Initializing APIChartCollection")

        if self.refresh_on_update:
            self.chart_cache.add_observer(self)

    def update(self):
        """
        Update the chart data when notified by ChartCache.
        """
        self.logger.debug("Updating all chart data.")
        self._charts_data = self.chart_cache.get_all_charts()
        self._log_charts_truncated()

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
        Manually refresh the chart data.
        """
        self.logger.debug("Manual refresh requested for all charts.")
        self.chart_cache.queue_refresh(self._update_charts_data)

    def _update_charts_data(self):
        """
        Update charts data from ChartCache.
        """
        self._charts_data = self.chart_cache.get_all_charts()
        self._log_charts_truncated()
        self.logger.debug("All chart data refreshed.")

    def close(self):
        """
        Remove this instance from the observer list in ChartCache, if it was added.
        """
        if self.refresh_on_update:
            self.logger.debug("Closing APIChartCollection")
            self.chart_cache.remove_observer(self)

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
    _instance = None
    _lock = threading.Lock()
    _observer_lock = threading.Lock()
    _observers = []
    _refresh_thread = None
    _refresh_interval = 10
    _refresh_condition = threading.Condition()
    _is_refreshing = False
    _refresh_stack = []

    def __new__(cls):
        """
        Create a new instance of ChartCache if one doesn't already exist.

        Returns:
            ChartCache: The singleton instance of ChartCache.
        """
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super(ChartCache, cls).__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if not self._initialized:
            self.logger = get_logger()
            self.middleware = MiddlewareClientManager.fetch()
            self._charts = self._fetch_all_charts()
            self._initialized = True
            self.logger.debug("ChartCache initialized.")

    def _fetch_all_charts(self) -> Dict[str, dict]:
        """
        Fetch all charts from the middleware and cache them.

        Returns:
            Dict[str, dict]: A dictionary of all charts and their resources.
        """
        try:
            self.logger.debug("Fetching all chart data from middleware.")
            charts = self.middleware.call('chart.release.query', [], {'extra': {'retrieve_resources': True}})
            if charts:
                self.logger.debug("All chart data fetched successfully.")
                return {chart['id']: chart for chart in charts}
            else:
                self.logger.warning("No chart data found.")
        except Exception as e:
            self.logger.error(f"Failed to fetch all chart data: {e}", exc_info=True)
        return {}

    def queue_refresh(self, callback):
        """
        Queue a manual refresh request to be executed after the next rolling refresh.

        Parameters:
            callback (function): The function to call after the refresh.
        """
        self.logger.debug("Queueing manual refresh.")
        with self._refresh_condition:
            self._refresh_stack.append(callback.__self__)
            while self._is_refreshing:
                self.logger.debug("Waiting for the current refresh to complete before queuing.")
                self._refresh_condition.wait()
            self.logger.debug("Performing manual refresh.")
            self.refresh()
            callback()
            self.logger.debug("Manual refresh complete.")

    def refresh(self) -> None:
        """
        Perform a synchronous refresh by fetching new data from the middleware and notifying observers.
        """
        with self._refresh_condition:
            while self._is_refreshing:
                self.logger.debug("Waiting for the current refresh to complete.")
                self._refresh_condition.wait()
            self._is_refreshing = True

        self.logger.debug("Starting refresh of chart cache.")
        self._charts = self._fetch_all_charts()
        self.logger.debug("Chart cache refreshed.")

        with self._refresh_condition:
            self._is_refreshing = False
            self._refresh_condition.notify_all()

        self._notify_observers()

    def _notify_observers(self):
        """
        Notify all registered observers of a data update.
        """
        with self._observer_lock:
            for observer in self._observers:
                if observer not in self._refresh_stack:
                    self.logger.debug(f"Notifying observer: {observer}")
                    observer.update()
            self.logger.debug("All observers notified.")
            self._refresh_stack = []

    def _start_rolling_refresh(self):
        """
        Start a background thread for rolling refresh.
        """
        if self._refresh_thread is None or not self._refresh_thread.is_alive():
            self._refresh_thread = threading.Thread(target=self._rolling_refresh)
            self._refresh_thread.daemon = True
            self._refresh_thread.start()

    def _rolling_refresh(self):
        """
        Perform rolling refresh at regular intervals.
        """
        while True:
            with self._refresh_condition:
                if not self._observers:
                    break
                self.refresh()
                self._refresh_condition.wait(self._refresh_interval)

    @property
    def charts(self) -> Dict[str, dict]:
        with self._lock:
            self.logger.debug("Accessing charts property.")
            return self._charts

    def get_chart(self, app_name: str) -> dict:
        self.logger.debug(f"Retrieving chart data for application: {app_name}")
        with self._lock:
            return self._charts.get(app_name, None)

    def get_all_charts(self) -> List[dict]:
        self.logger.debug("Retrieving all chart data.")
        with self._lock:
            return list(self._charts.values())

    def add_observer(self, observer: ChartObserver):
        self.logger.debug(f"Adding observer: {observer}")
        with self._observer_lock:
            self._observers.append(observer)
            if len(self._observers) == 1:
                self._start_rolling_refresh()

    def remove_observer(self, observer: ChartObserver):
        self.logger.debug(f"Removing observer: {observer}")
        with self._observer_lock:
            self._observers.remove(observer)

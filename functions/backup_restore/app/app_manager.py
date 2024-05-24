import time
import logging
import threading
from charts.api_fetch import APIChartFetcher

class AppManager:
    """
    A class to manage application status operations.
    """

    def __init__(self):
        """
        Initialize the AppManager class.

        Retrieves the already configured logger.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.status_event = threading.Event()

    def wait_for_app_active(self, app_name: str, timeout: int = 600) -> bool:
        """
        Waits for the specified application to become ACTIVE.

        Parameters:
            app_name (str): The name of the application to wait for.
            timeout (int): The maximum time to wait for the application to become ACTIVE, in seconds.

        Returns:
            bool: True if the application becomes ACTIVE within the timeout, False otherwise.
        """
        self.logger.debug(f"Waiting for {app_name} to become ACTIVE...")
        deadline = time.time() + timeout

        def status_callback():
            self.status_event.set()

        with APIChartFetcher(app_name, refresh_on_update=True) as fetcher:
            fetcher.register_status_callback(status_callback)

            while time.time() < deadline:
                status = fetcher.status
                self.logger.debug(f"Status of {app_name}: {status}")
                if status == 'ACTIVE':
                    self.logger.debug(f"{app_name} is now ACTIVE.")
                    return True

                self.logger.debug(f"{app_name} is not ACTIVE yet. Waiting for a status update...")
                self.status_event.wait(timeout)
                self.status_event.clear()

        self.logger.warning(f"Timed out waiting for {app_name} to become ACTIVE.")
        return False

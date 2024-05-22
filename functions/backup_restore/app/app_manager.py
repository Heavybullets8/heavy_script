import time
import logging
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

    def wait_for_app_active(self, app_name: str, timeout: int = 600, interval: int = 10) -> bool:
        """
        Waits for the specified application to become ACTIVE.

        Parameters:
            app_name (str): The name of the application to wait for.
            timeout (int): The maximum time to wait for the application to become ACTIVE, in seconds.
            interval (int): The interval between checks, in seconds.

        Returns:
            bool: True if the application becomes ACTIVE within the timeout, False otherwise.
        """
        self.logger.debug(f"Waiting for {app_name} to become ACTIVE...")
        deadline = time.time() + timeout
        fetcher = APIChartFetcher(app_name)
        self.logger.debug(f"Starting to wait for app {app_name} to become ACTIVE.")

        while time.time() < deadline:
            fetcher.refresh()
            status = fetcher.status
            self.logger.debug(f"Status of {app_name}: {status}")
            if status == 'ACTIVE':
                self.logger.debug(f"{app_name} is now ACTIVE.")
                return True

            self.logger.debug(f"{app_name} is not ACTIVE yet. Waiting for {interval} seconds...")
            time.sleep(interval)

        self.logger.warning(f"Timed out waiting for {app_name} to become ACTIVE.")
        return False

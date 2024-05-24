import base64
import time
import logging
from pathlib import Path
from kubernetes.client.rest import ApiException
from utils.shell import run_command
from utils.singletons import KubernetesClientManager
from utils.type_check import type_check

class DatabaseUtils:
    """
    Utility class for database operations.
    """

    @type_check
    def __init__(self, namespace: str):
        """
        Initialize the DatabaseUtils class.

        Parameters:
            namespace (str): The namespace to operate in.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.v1_client = KubernetesClientManager.fetch()
        self.namespace = namespace

    def fetch_primary_pod(self, timeout=300, interval=5) -> str:
        """
        Wait for the primary pod to be in the 'Running' state and return its name.

        Parameters:
            timeout (int): The maximum time to wait for the primary pod to be running (default is 300 seconds).
            interval (int): The interval time between checks (default is 5 seconds).

        Returns:
            str: The name of the primary pod if found and running, otherwise None.
        """
        deadline = time.time() + timeout
        self.logger.debug(f"Waiting for primary pod in namespace '{self.namespace}' with timeout={timeout} and interval={interval}")
        
        while time.time() < deadline:
            try:
                pods = self.v1_client.list_namespaced_pod(self.namespace, label_selector='role=primary')
                for pod in pods.items:
                    if pod.status.phase == 'Running':
                        self.logger.debug(f"Primary pod is running: {pod.metadata.name}")
                        return pod.metadata.name
            except ApiException as e:
                self.logger.error(f"Failed to list pods: {e}")
            time.sleep(interval)
        
        self.logger.error("Timed out waiting for primary pod.")
        return None

    def fetch_database_name(self) -> str:
        """
        Retrieve the database name from Kubernetes secrets.

        Returns:
            str: The database name if found, otherwise None.
        """
        db_url = self._fetch_secret_data(suffix="-cnpg-main-urls", key='std')
        if db_url:
            return self._extract_database_name(db_url)
        return None

    def fetch_database_user(self) -> str:
        """
        Retrieve the database username from Kubernetes secrets.

        Returns:
            str: The database username if found, otherwise None.
        """
        return self._fetch_secret_data(suffix="-cnpg-main-user", key='username')

    def _fetch_secret_data(self, suffix: str, key: str) -> str:
        """
        Retrieve specific data from Kubernetes secrets.

        Parameters:
            suffix (str): The suffix of the secret name to search for.
            key (str): The key of the data to retrieve from the secret.

        Returns:
            str: The decoded data from the secret if found, otherwise None.
        """
        self.logger.debug(f"Fetching secret data with suffix '{suffix}' and key '{key}' in namespace '{self.namespace}'")
        
        try:
            secrets = self.v1_client.list_namespaced_secret(self.namespace)
            for secret in secrets.items:
                if secret.metadata.name.endswith(suffix) and key in secret.data:
                    decoded_data = base64.b64decode(secret.data[key]).decode('utf-8')
                    self.logger.debug(f"Data retrieved from secret '{secret.metadata.name}': {decoded_data}")
                    return decoded_data
        except ApiException as e:
            self.logger.error(f"Failed to fetch secrets: {e}", exc_info=True)
        
        self.logger.warning(f"No secret found with suffix '{suffix}' and key '{key}'")
        return None

    def _extract_database_name(self, db_url: str) -> str:
        """
        Extract the database name from a PostgreSQL URL.

        Parameters:
            db_url (str): The PostgreSQL URL containing the database name.

        Returns:
            str: The extracted database name if found, otherwise None.
        """
        try:
            database_name = db_url.split('/')[-1]
            self.logger.debug(f"Extracted database name: {database_name}")
            return database_name
        except Exception as e:
            self.logger.error(f"Failed to extract database name from URL '{db_url}': {e}")
            return None

    def start_app(self, app_name: str) -> bool:
        """
        Start the application using the heavy_script.sh script.

        Returns:
            bool: True if the app was started successfully, False otherwise.
        """
        script_path = Path(__file__).parent.parent.parent.parent / "heavy_script.sh"
        command = f"bash \"{script_path}\" --no-self-update --no-config app --start {app_name}"
        result = run_command(command)
        if result.is_success():
            self.logger.debug(f"App {app_name} started successfully.")
        else:
            self.logger.error(f"Failed to start app {app_name}: {result.get_error()}")
        return result.is_success()

    def stop_app(self, app_name: str):
        """
        Stop the application using the heavy_script.sh script.
        """
        script_path = Path(__file__).parent.parent.parent.parent / "heavy_script.sh"
        command = f"bash \"{script_path}\" --no-self-update --no-config app --stop {app_name}"
        result = run_command(command)
        if result.is_success():
            self.logger.debug(f"App {app_name} stopped successfully.")
        else:
            self.logger.error(f"Failed to stop app {app_name}: {result.get_error()}")
            raise RuntimeError(f"Failed to stop app {app_name}: {result.get_error()}")
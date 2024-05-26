import atexit
import threading
from middlewared.client import Client
from kubernetes import client, config
from utils.logger import get_logger

class MiddlewareClientManager:
    """
    Singleton class to manage the Middleware client connection.
    This class ensures that the connection to the middleware services is managed centrally,
    providing easy access and proper closure of the client.
    """
    _middleware = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._middleware is None:
            with cls._lock:
                if cls._middleware is None:
                    cls._middleware = super(MiddlewareClientManager, cls).__new__(cls)
        return cls._middleware

    @classmethod
    def fetch(cls):
        """
        Get the singleton instance of the Middleware client. If it does not exist, create it.

        Returns:
            Client: The Middleware client instance.
        """
        logger = get_logger()
        if cls._middleware is None:
            with cls._lock:
                if cls._middleware is None:
                    cls._middleware = Client()
                    atexit.register(cls.close)
                    logger.debug("Middleware client initialized.")
        return cls._middleware

    @classmethod
    def close(cls) -> None:
        """
        Close the Middleware client if it exists and clean up the instance.
        """
        logger = get_logger()
        if cls._middleware:
            cls._middleware.close()
            cls._middleware = None
            logger.debug("Middleware client closed.")

class KubernetesClientManager:
    """
    Singleton class to manage the Kubernetes client connection.
    This class ensures that the Kubernetes API client is managed centrally,
    providing easy access, proper closure of the client, and methods to check the health of the connection.
    """
    _k8s_client = None
    _config_file = '/etc/rancher/k3s/k3s.yaml'

    @classmethod
    def fetch(cls) -> client.CoreV1Api:
        """
        Get the singleton instance of the Kubernetes CoreV1Api client.
        If it does not exist, create it using the specified configuration file.

        Returns:
            client.CoreV1Api: The Kubernetes CoreV1Api client instance.
        """
        logger = get_logger()
        if cls._k8s_client is None:
            logger.debug("Kubernetes client is None, initializing...")
            cls.reload_config()
            atexit.register(cls.close)
        return cls._k8s_client

    @classmethod
    def reload_config(cls) -> None:
        """
        Reload the Kubernetes configuration and update the client.
        This is useful if there are changes to the configuration that need to be applied.
        """
        logger = get_logger()
        try:
            logger.debug(f"Loading Kubernetes configuration from {cls._config_file}")
            config.load_kube_config(config_file=cls._config_file)
            logger.debug("Kubernetes configuration loaded")
            cls._k8s_client = client.CoreV1Api()
            logger.debug("Kubernetes CoreV1Api client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to reload Kubernetes configuration: {e}", exc_info=True)

    @classmethod
    def health_check(cls) -> bool:
        """
        Perform a health check by retrieving the API server version.
        Returns True if the connection is valid, False otherwise.

        Returns:
            bool: True if the connection is valid, False otherwise.
        """
        logger = get_logger()
        logger.debug("Performing health check on Kubernetes client...")
        try:
            cls.fetch()
            version_api = client.VersionApi(cls._k8s_client.api_client)
            version_info = version_api.get_code()
            logger.debug(f"Connected to Kubernetes API Server with version: {version_info.major}.{version_info.minor}")
            return True
        except client.ApiException as e:
            logger.error(f"Failed to connect to Kubernetes API Server: {e}", exc_info=True)
            return False

    @classmethod
    def close(cls) -> None:
        """
        Clean up the Kubernetes client instance if it exists.
        """
        logger = get_logger()
        if cls._k8s_client:
            logger.debug("Closing Kubernetes client connection...")
            cls._k8s_client = None

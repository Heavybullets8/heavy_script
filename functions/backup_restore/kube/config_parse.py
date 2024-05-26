import json
from pathlib import Path
from utils.logger import get_logger
from utils.singletons import MiddlewareClientManager
from utils.type_check import type_check

class KubeConfigReader:
    """
    Reads the Kubernetes configuration from a backup file.
    """
    @type_check
    def __init__(self, backupFile: Path):
        """
        Initialize the KubeConfigReader with the path to the backup file.

        Parameters:
            backupFile (Path): The path to the backup file containing Kubernetes configuration.
        """
        self.logger = get_logger()
        self.backupFile = backupFile
        self.config_data = self._load_config()

    def _load_config(self) -> dict:
        """
        Load the configuration data from the backup file.

        Returns:
            dict: The configuration data.

        Raises:
            RuntimeError: If the configuration file cannot be read or parsed.
        """
        try:
            with self.backupFile.open('r') as f:
                return json.load(f)
        except Exception as e:
            self.logger.error("Critical: Failed to fetch Kubernetes configuration.", exc_info=True)
            raise RuntimeError("Failed to fetch essential Kubernetes configuration.") from e

    @property
    def pool(self) -> str:
        """Returns the pool configuration."""
        return self.config_data.get('pool')

    @property
    def dataset(self) -> str:
        """Returns the dataset configuration."""
        return self.config_data.get('dataset')

    @property
    def cluster_cidr(self) -> str:
        """Returns the cluster CIDR configuration."""
        return self.config_data.get('cluster_cidr')

    @property
    def service_cidr(self) -> str:
        """Returns the service CIDR configuration."""
        return self.config_data.get('service_cidr')

    @property
    def cluster_dns_ip(self) -> str:
        """Returns the cluster DNS IP configuration."""
        return self.config_data.get('cluster_dns_ip')

    @property
    def node_ip(self) -> str:
        """Returns the node IP configuration."""
        return self.config_data.get('node_ip')

    @property
    def configure_gpus(self) -> bool:
        """Returns the GPU configuration setting."""
        return self.config_data.get('configure_gpus', False)

    @property
    def servicelb(self) -> bool:
        """Returns the ServiceLB configuration setting."""
        return self.config_data.get('servicelb', False)

    @property
    def passthrough_mode(self) -> bool:
        """Returns the passthrough mode setting."""
        return self.config_data.get('passthrough_mode', False)

    @property
    def metrics_server(self) -> bool:
        """Returns the metrics server configuration setting."""
        return self.config_data.get('metrics_server', False)

class KubeAPIFetch:
    """
    Fetches the Kubernetes configuration from the middleware.
    """
    def __init__(self):
        """
        Initialize the KubeAPIFetch and fetch the Kubernetes configuration from the middleware.
        """
        self.logger = get_logger()
        self.middleware = MiddlewareClientManager.fetch()
        self.config_data = self._fetch_kubernetes_config()

    def _fetch_kubernetes_config(self) -> dict:
        """
        Fetch the entire Kubernetes configuration from the middleware.

        Returns:
            dict: The Kubernetes configuration data.

        Raises:
            RuntimeError: If the configuration data cannot be fetched.
        """
        try:
            config_data = self.middleware.call('kubernetes.config')
            self.logger.debug("Successfully fetched Kubernetes configuration.")
            return config_data
        except Exception as e:
            self.logger.error("Critical: Failed to fetch Kubernetes configuration.", exc_info=True)
            raise RuntimeError("Failed to fetch essential Kubernetes configuration.") from e

    @property
    def pool(self) -> str:
        """
        Returns the Kubernetes pool name.

        Returns:
            str: The pool name.

        Raises:
            ValueError: If pool information is missing in the configuration.
        """
        if 'pool' not in self.config_data:
            raise ValueError("Pool information is missing in the Kubernetes configuration.")
        return self.config_data['pool']

    @property
    def dataset(self) -> str:
        """
        Returns the Kubernetes dataset name.

        Returns:
            str: The dataset name.

        Raises:
            ValueError: If dataset information is missing in the configuration.
        """
        if 'dataset' not in self.config_data:
            raise ValueError("Dataset information is missing in the Kubernetes configuration.")
        return self.config_data['dataset']

    @property
    def cluster_cidr(self) -> str:
        """Returns the cluster CIDR."""
        return self.config_data.get('cluster_cidr')

    @property
    def service_cidr(self) -> str:
        """Returns the service CIDR."""
        return self.config_data.get('service_cidr')

    @property
    def cluster_dns_ip(self) -> str:
        """Returns the cluster DNS IP."""
        return self.config_data.get('cluster_dns_ip')

    @property
    def node_ip(self) -> str:
        """Returns the node IP."""
        return self.config_data.get('node_ip')

    @property
    def configure_gpus(self) -> bool:
        """Returns the GPU configuration setting."""
        return self.config_data.get('configure_gpus', False)

    @property
    def servicelb(self) -> bool:
        """Returns the ServiceLB configuration setting."""
        return self.config_data.get('servicelb', False)

    @property
    def passthrough_mode(self) -> bool:
        """Returns the passthrough mode setting."""
        return self.config_data.get('passthrough_mode', False)

    @property
    def metrics_server(self) -> bool:
        """Returns the metrics server configuration setting."""
        return self.config_data.get('metrics_server', False)

import json
from pathlib import Path
from utils.logger import get_logger
from utils.singletons import MiddlewareClientManager
from utils.type_check import type_check
from utils.check_job import check_job_status

class KubeRestoreConfig:
    """
    Class for restoring Kubernetes configuration from a backup file.
    """
    @type_check
    def __init__(self, backup_file: Path):
        """
        Initialize the KubeRestoreConfig class.

        Parameters:
        - backup_file (Path): Path to the backup file containing the Kubernetes configuration.
        """
        self.logger = get_logger()
        self.middleware = MiddlewareClientManager.fetch()
        self.backup_file = backup_file
        self.logger.debug(f"KubeRestoreConfig initialized with backup file: {self.backup_file}")

    def restore(self):
        """
        Restore Kubernetes configuration from a backup file.

        Reads the Kubernetes configuration from a JSON file and updates the current configuration.
        """
        self.logger.debug(f"Starting restore of Kubernetes configuration from {self.backup_file}")
        try:
            with open(self.backup_file, 'r') as f:
                config_data = json.load(f)
            self.logger.debug(f"Loaded configuration data from {self.backup_file}: {config_data}")

            # Prepare the data for restoration
            restore_data = {
                "pool": config_data["pool"],
                "cluster_cidr": config_data["cluster_cidr"],
                "service_cidr": config_data["service_cidr"],
                "cluster_dns_ip": config_data["cluster_dns_ip"],
                "route_v4_interface": config_data["route_v4_interface"],
                "route_v4_gateway": config_data["route_v4_gateway"],
                "route_v6_interface": config_data["route_v6_interface"],
                "route_v6_gateway": config_data["route_v6_gateway"],
                "node_ip": config_data["node_ip"],
                "configure_gpus": config_data["configure_gpus"],
                "servicelb": config_data["servicelb"],
                "passthrough_mode": config_data["passthrough_mode"],
                "metrics_server": config_data["metrics_server"]
            }
            self.logger.debug(f"Prepared restore data: {restore_data}")

            job_id = self.middleware.call('kubernetes.update', restore_data)
            self.logger.debug(f"Restore job initiated with job ID: {job_id}")

            if not check_job_status(job_id):
                self.logger.error("Failed to restore Kubernetes configuration due to job error.")
            else:
                self.logger.info("Successfully restored Kubernetes configuration.")
        except Exception as e:
            self.logger.error(f"Failed to restore Kubernetes configuration: {e}", exc_info=True)
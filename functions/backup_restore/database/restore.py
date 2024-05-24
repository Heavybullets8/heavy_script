import subprocess
import time
import gzip
import logging
from typing import Tuple, Dict
from pathlib import Path
from kubernetes.client.rest import ApiException

from utils.type_check import type_check
from utils.singletons import KubernetesClientManager
from charts.api_fetch import APIChartFetcher
from .utils import DatabaseUtils

class RestoreCNPGDatabase:
    """
    Class responsible for restoring a CNPG (Cloud Native PostgreSQL) database from a backup file.
    """

    @type_check
    def __init__(self, app_name: str, backup_file: Path):
        """
        Initialize the RestoreCNPGDatabase class.

        Parameters:
            app_name (str): The name of the application.
            chart_name (str): The name of the chart.
            backup_file (Path): The path to the backup file.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.v1_client = KubernetesClientManager.fetch()
        self.chart_info = APIChartFetcher(app_name)
                
        self.backup_file = backup_file
        self.app_name = app_name
        self.chart_name = self.chart_info.chart_name
        self.namespace = f"ix-{app_name}"
        self.db_utils = DatabaseUtils(self.namespace)
        self.primary_pod = None
        self.command = None
        self.open_mode = None

        if self.chart_name != "immich":
            self.database_name = self.db_utils.fetch_database_name()
            self.database_user = self.db_utils.fetch_database_user() or self.database_name       
        else:
            self.database_user = None
            self.database_name = None

        self.logger.debug(f"RestoreCNPGDatabase initialized for app: {self.app_name} with backup file: {self.backup_file}")

    def restore(self, timeout=300, interval=5) -> Dict[str, str]:
        """
        Restore a database from a backup file.

        Parameters:
            timeout (int): Maximum time to wait for the primary pod to be found.
            interval (int): Interval between retries to find the primary pod.

        Returns:
            dict: Result containing status and message.
        """
        self.logger.debug(f"Starting database restore process for app: {self.app_name}")

        result = {
            "success": False,
            "message": ""
        }

        if not self.backup_file.exists():
            message = "Backup file not found."
            self.logger.error(message)
            result["message"] = message
            return result

        if not KubernetesClientManager.health_check():
            self.logger.debug("Kubernetes cluster is not healthy. Reloading config.")
            KubernetesClientManager.reload_config()

        app_status = self.chart_info.status
        was_stopped = False

        if app_status == "STOPPED":
            self.logger.debug(f"App {self.app_name} is stopped, starting it for restore.")
            if not self.db_utils.start_app(self.app_name):
                message = f"Failed to start app {self.app_name}."
                self.logger.error(message)
                result["message"] = message
                return result
            was_stopped = True

        self.primary_pod = self.db_utils.fetch_primary_pod(timeout, interval)
        if not self.primary_pod:
            message = "Primary pod not found."
            self.logger.error(message)
            result["message"] = message

            if was_stopped:
                self.logger.debug(f"Stopping app {self.app_name} after restore failure.")
                self.db_utils.stop_app(self.app_name)

            return result

        self.command, self.open_mode = self._get_restore_command()

        try:
            result = self._execute_restore_command()

            if not result["success"]:
                if was_stopped:
                    self.logger.debug(f"Stopping app {self.app_name} after restore failure.")
                    self.db_utils.stop_app(self.app_name)
                return result

            result["success"] = True
            result["message"] = "Database restored successfully."

        except Exception as e:
            message = f"Failed to execute restore command: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        if was_stopped:
            self.logger.debug(f"Stopping app {self.app_name} after successful restore.")
            self.db_utils.stop_app(self.app_name)

        return result

    def _get_restore_command(self) -> Tuple[str, str]:
        """
        Get the appropriate restore command based on the chart name.

        Returns:
            Tuple[str, str]: The restore command and the file open mode.
        """
        if self.chart_name == "immich":
            command = [
                "k3s", "kubectl", "exec",
                "--namespace", self.namespace,
                "--stdin",
                "--container", "postgres",
                self.primary_pod,
                "--",
                "psql",
                "--echo-errors",
                "--quiet"
            ]
            open_mode = 'r'
        else:
            command = [
                "k3s", "kubectl", "exec",
                "--namespace", self.namespace,
                "--stdin",
                "--container", "postgres",
                self.primary_pod,
                "--",
                "pg_restore",
                f"--role={self.database_user}",
                f"--dbname={self.database_name}",
                "--clean",
                "--if-exists",
                "--no-owner",
                "--no-privileges",
                "--single-transaction"
            ]
            open_mode = 'rb'
        
        self.logger.debug(f"Restore command for app {self.app_name}: {command}")
        return command, open_mode

    def _execute_restore_command(self, retries=3, wait=5) -> Dict[str, str]:
        """
        Execute the restore command on the primary pod with retry logic in case of deadlock.

        Parameters:
            retries (int): Number of times to retry in case of deadlock.
            wait (int): Time to wait between retries.

        Returns:
            dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }
        self.logger.debug(f"Executing restore command on pod: {self.primary_pod} with dump file: {self.backup_file}")

        for attempt in range(retries):
            try:
                if self.backup_file.suffix == '.gz':
                    with gzip.open(self.backup_file, 'rb') as f:
                        process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        stdout, stderr = process.communicate(input=f.read())
                else:
                    with open(self.backup_file, self.open_mode) as f:
                        process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=(self.open_mode == 'r'))
                        stdout, stderr = process.communicate(input=f.read())

                if stdout:
                    self.logger.debug(stdout)
                if stderr:
                    self.logger.debug(stderr)

                if process.returncode == 0:
                    message = "Database restored successfully."
                    result["success"] = True
                    result["message"] = message
                    return result
                else:
                    message = f"Restore command failed with return code {process.returncode}"
                    self.logger.error(message)
                    result["message"] = f"{result['message']} Attempt {attempt + 1}/{retries}: {message}"

            except ApiException as e:
                message = f"Failed to restore database: {e}"
                self.logger.error(message, exc_info=True)
                result["message"] = message
                return result
            except IOError as e:
                message = f"IO error during restore process: {e}"
                self.logger.error(message, exc_info=True)
                result["message"] = message
                return result

            # Check for deadlock and retry if detected
            if 'deadlock detected' in stderr:
                message = f"Deadlock detected. Retrying {attempt + 1}/{retries}..."
                self.logger.warning(message)
                result["message"] = f"{result['message']} {message}"
                time.sleep(wait)
            else:
                break

        result["message"] = f"{result['message']} Restore failed after retrying."
        self.logger.error(result["message"])
        return result

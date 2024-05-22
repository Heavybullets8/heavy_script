import subprocess
import logging
import gzip
from pathlib import Path
from typing import Dict
from utils.type_check import type_check
from utils.singletons import KubernetesClientManager
from .utils import DatabaseUtils

class BackupCNPGDatabase:
    """
    Class responsible for backing up a CNPG (Cloud Native PostgreSQL) database.
    """

    @type_check
    def __init__(self, backup_dir: Path, app_name: str, chart_name: str):
        """
        Initialize the BackupCNPGDatabase class.

        Parameters:
            backup_dir (Path): Directory where the backup will be stored.
            app_name (str): Name of the application.
            chart_name (str): Name of the chart.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.v1_client = KubernetesClientManager.fetch()
        self.backup_dir = backup_dir
        self.app_name = app_name
        self.namespace = f"ix-{app_name}"
        self.chart_name = chart_name
        self.db_utils = DatabaseUtils(self.namespace)
        self.primary_pod = None
        self.database_name = None
        self.dump_command = None
        self.output_file = self.backup_dir / f"{self.app_name}.sql.gz"
        self.temp_file = self.backup_dir / f"{self.app_name}.sql"
        self.error = None

    def backup(self, timeout=300, interval=5) -> Dict[str, str]:
        """
        Backup the database to a file.

        Parameters:
            timeout (int): Maximum time to wait for the primary pod to be found.
            interval (int): Interval between retries to find the primary pod.

        Returns:
            dict: Result containing status and message.
        """
        self.logger.debug(f"Starting database backup process for app: {self.app_name} in namespace: {self.namespace}")

        result = {
            "success": False,
            "message": ""
        }

        self.primary_pod = self._get_primary_pod(timeout, interval)
        if not self.primary_pod:
            message = "Primary pod not found."
            self.logger.error(message)
            result["message"] = message
            return result

        if self.chart_name != "immich":
            self.database_name = self._get_database_name()
            if not self.database_name:
                message = "Database name retrieval failed."
                self.logger.error(message)
                result["message"] = message
                return result

        try:
            self.dump_command = self._get_dump_command()
            self.logger.debug(f"Executing dump command: {self.dump_command}")

            result = self._execute_backup_command()

            if not result["success"]:
                return result

            if self.chart_name == "immich":
                self.logger.debug("Modifying dump data for immich database.")
                self._modify_dump_for_immich()

            self._compress_backup()
            result["success"] = True
            result["message"] = f"Database dumped and compressed successfully to {self.output_file}"

        except Exception as e:
            message = f"Failed to execute dump command: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        return result

    def _get_primary_pod(self, timeout, interval) -> str:
        """
        Fetch the primary pod for the database.

        Parameters:
            timeout (int): Maximum time to wait for the primary pod to be found.
            interval (int): Interval between retries to find the primary pod.

        Returns:
            str: The name of the primary pod if found, None otherwise.
        """
        self.logger.debug(f"Fetching primary pod for app: {self.app_name} with timeout: {timeout} and interval: {interval}")
        primary_pod = self.db_utils.fetch_primary_pod(timeout, interval)
        if primary_pod:
            self.logger.debug(f"Primary pod found: {primary_pod}")
        return primary_pod

    def _get_database_name(self) -> str:
        """
        Fetch the database name.

        Returns:
            str: The name of the database if found, None otherwise.
        """
        self.logger.debug(f"Fetching database name for app: {self.app_name}")
        database_name = self.db_utils.fetch_database_name()
        if not database_name:
            self.logger.error("Failed to get database name.")
            return None
        self.logger.debug(f"Database name found: {database_name}")
        return database_name

    def _get_dump_command(self) -> list:
        """
        Get the appropriate dump command based on the chart name.

        Returns:
            list: The dump command as a list of strings.
        """
        if self.chart_name == "immich":
            dump_command = [
                "k3s", "kubectl", "exec",
                "--namespace", self.namespace,
                "--container", "postgres",
                self.primary_pod,
                "--",
                "pg_dumpall",
                "--clean",
                "--if-exists"
            ]
        else:
            dump_command = [
                "k3s", "kubectl", "exec",
                "--namespace", self.namespace,
                "--container", "postgres",
                self.primary_pod,
                "--",
                "pg_dump",
                "--format=custom",
                f"--dbname={self.database_name}"
            ]

        self.logger.debug(f"Dump command for app {self.app_name}: {' '.join(dump_command)}")
        return dump_command

    def _execute_backup_command(self) -> Dict[str, str]:
        """
        Execute the backup command using subprocess and write to the temporary file.

        Returns:
            dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }
        self.logger.debug(f"Executing backup command: {self.dump_command}")
        try:
            with subprocess.Popen(self.dump_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=False) as process:
                stdout, stderr = process.communicate()

                # Log the error output
                if stderr:
                    self.logger.debug(stderr.decode('utf-8'))

                if process.returncode != 0:
                    message = f"Backup command failed with return code {process.returncode}"
                    self.logger.error(message)
                    result["message"] = message
                    return result

                # Write the output to the temporary file
                write_mode = 'w' if self.chart_name == "immich" else 'wb'
                with open(self.temp_file, write_mode) as f:
                    f.write(stdout.decode('utf-8') if self.chart_name == "immich" else stdout)

            result["success"] = True

        except Exception as e:
            message = f"Failed to execute backup command: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        return result

    def _compress_backup(self) -> None:
        """
        Compress the temporary backup file to gzip format and remove the temporary file.
        """
        self.logger.debug(f"Compressing the backup file {self.temp_file} to {self.output_file}")
        try:
            with open(self.temp_file, 'rb') as f_in:
                with gzip.open(self.output_file, 'wb') as f_out:
                    f_out.writelines(f_in)
            self.temp_file.unlink()  # Remove the temporary file
            self.logger.debug(f"Backup file compressed successfully.")
        except IOError as e:
            message = f"Failed to compress backup file: {e}"
            self.logger.error(message, exc_info=True)
            raise

    def _modify_dump_for_immich(self) -> None:
        """
        Modify the dump data for immich database.
        """
        self.logger.debug("Modifying dump data for immich database.")
        try:
            with open(self.temp_file, 'r') as f:
                data = f.read().splitlines()
                modified_data = "\n".join(
                    '-- ' + line if 'DROP ROLE IF EXISTS postgres;' in line or 'CREATE ROLE postgres;' in line
                    else "SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);" if "SELECT pg_catalog.set_config('search_path', '', false);" in line
                    else line
                    for line in data
                )
            with open(self.temp_file, 'w') as f:
                f.write(modified_data)

            self.logger.debug(f"Dump data for immich modified successfully.")
        except IOError as e:
            message = f"Failed to modify dump data for immich: {e}"
            self.logger.error(message, exc_info=True)
            raise

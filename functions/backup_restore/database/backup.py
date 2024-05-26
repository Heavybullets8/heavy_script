import subprocess
import gzip
from pathlib import Path
from typing import Dict
from utils.type_check import type_check
from .base import CNPGBase

class BackupCNPGDatabase(CNPGBase):
    """
    Class responsible for backing up a CNPG (Cloud Native PostgreSQL) database.
    """

    @type_check
    def __init__(self, backup_dir: Path, app_name: str):
        """
        Initialize the BackupCNPGDatabase class.

        Parameters:
            backup_dir (Path): Directory where the backup will be stored.
            app_name (str): Name of the application.
        """
        super().__init__(app_name)
        self.backup_dir = backup_dir
        self.output_file = self.backup_dir / f"{self.app_name}.sql.gz"
        self.temp_file = self.backup_dir / f"{self.app_name}.sql"

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

    def _compress_backup(self) -> None:
        """
        Compress the temporary backup file to gzip format and remove the temporary file.
        """
        self.logger.debug(f"Compressing the backup file {self.temp_file} to {self.output_file}")
        try:
            with open(self.temp_file, 'rb') as f_in:
                with gzip.open(self.output_file, 'wb') as f_out:
                    f_out.writelines(f_in)
            self.temp_file.unlink()
            self.logger.debug(f"Backup file compressed successfully.")
        except IOError as e:
            message = f"Failed to compress backup file: {e}"
            self.logger.error(message, exc_info=True)
            raise

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

        app_status = self.chart_info.status
        was_stopped = False

        if app_status == "STOPPED":
            self.logger.debug(f"App {self.app_name} is stopped, starting it for backup.")
            if not self.start_app(self.app_name):
                message = f"Failed to start app {self.app_name}."
                self.logger.error(message)
                result["message"] = message
                return result
            was_stopped = True

        self.primary_pod = self.fetch_primary_pod(timeout, interval)
        if not self.primary_pod:
            message = "Primary pod not found."
            self.logger.error(message)
            result["message"] = message

            if was_stopped:
                self.logger.debug(f"Stopping app {self.app_name} after backup failure.")
                self.stop_app(self.app_name)

            return result

        try:
            self.dump_command = self._get_dump_command()
            self.logger.debug(f"Executing dump command: {self.dump_command}")

            result = self._execute_backup_command()

            if not result["success"]:
                if was_stopped:
                    self.logger.debug(f"Stopping app {self.app_name} after backup failure.")
                    self.stop_app(self.app_name)
                return result

            if self.chart_info.chart_name == "immich":
                self.logger.debug("Modifying dump data for immich database.")
                self._modify_dump_for_immich()

            self._compress_backup()
            result["success"] = True
            result["message"] = f"Database dumped and compressed successfully to {self.output_file}"

        except Exception as e:
            message = f"Failed to execute dump command: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        if was_stopped:
            self.logger.debug(f"Stopping app {self.app_name} after successful backup.")
            self.stop_app(self.app_name)

        return result

    def _get_dump_command(self) -> list:
        """
        Get the appropriate dump command based on the chart name.

        Returns:
            list: The dump command as a list of strings.
        """
        if self.chart_info.chart_name == "immich":
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
                write_mode = 'w' if self.chart_info.chart_name == "immich" else 'wb'
                with open(self.temp_file, write_mode) as f:
                    f.write(stdout.decode('utf-8') if self.chart_info.chart_name == "immich" else stdout)

            result["success"] = True

        except Exception as e:
            message = f"Failed to execute backup command: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        return result

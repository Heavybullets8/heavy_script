import re
import yaml
from pathlib import Path
from datetime import datetime

from zfs.cache import ZFSCache
from utils.shell import run_command
from utils.type_check import type_check
from utils.logger import get_logger

class ZFSSnapshotManager:
    """
    Class responsible for managing ZFS snapshots, including creation, deletion, and rollback operations.
    """

    @type_check
    def __init__(self):
        """
        Initialize the ZFSSnapshotManager class.
        """
        self.logger = get_logger()
        self.cache = ZFSCache()

    @type_check
    def _cleanup_snapshots(self, dataset_paths: list, retention_number: int) -> list:
        """
        Cleanup older snapshots, retaining only a specified number of the most recent ones.

        Parameters:
        - dataset_paths (list): List of paths to datasets.
        - retention_number (int): Number of recent snapshots to retain.

        Returns:
        - list: A list of error messages, if any.
        """
        errors = []
        for path in dataset_paths:
            if path not in self.cache.datasets:
                error_msg = f"Dataset {path} does not exist."
                self.logger.error(error_msg)
                errors.append(error_msg)
                continue

            matching_snapshots = [snap for snap in self.cache.snapshots if snap.startswith(f"{path}@HeavyScript--")]
            matching_snapshots.sort(key=lambda x: datetime.strptime(re.search(r'HeavyScript--\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}', x).group(), "HeavyScript--%Y-%m-%d_%H:%M:%S"))

            self.logger.debug(f"Found {len(matching_snapshots)} snapshots for dataset path {path}.")

            if len(matching_snapshots) > retention_number:
                snapshots_to_delete = matching_snapshots[:-retention_number]
                for snapshot in snapshots_to_delete:
                    delete_command = f"/sbin/zfs destroy \"{snapshot}\""
                    delete_result = run_command(delete_command)
                    if delete_result.is_success():
                        self.cache.remove_snapshot(snapshot)
                        self.logger.debug(f"Deleted snapshot: {snapshot}")
                    else:
                        error_msg = f"Failed to delete snapshot {snapshot}: {delete_result.get_error()}"
                        self.logger.error(error_msg)
                        errors.append(error_msg)
        return errors

    @type_check
    def create_snapshots(self, snapshot_name, dataset_paths: list, retention_number: int) -> list:
        """
        Create snapshots for specified ZFS datasets and cleanup old snapshots.

        Parameters:
        - snapshot_name (str): Name of the snapshot.
        - dataset_paths (list): List of paths to create snapshots for.
        - retention_number (int): Number of recent snapshots to retain.

        Returns:
        - list: A list of error messages, if any.
        """
        errors = []
        for path in dataset_paths:
            if path not in self.cache.datasets:
                error_msg = f"Dataset {path} does not exist."
                self.logger.error(error_msg)
                errors.append(error_msg)
                continue

            snapshot_full_name = f"{path}@{snapshot_name}"
            command = f"/sbin/zfs snapshot \"{snapshot_full_name}\""
            result = run_command(command)
            if result.is_success():
                self.cache.add_snapshot(snapshot_full_name)
                self.logger.debug(f"Created snapshot: {snapshot_full_name}")
            else:
                error_msg = f"Failed to create snapshot for {snapshot_full_name}: {result.get_error()}"
                self.logger.error(error_msg)
                errors.append(error_msg)
        
        cleanup_errors = self._cleanup_snapshots(dataset_paths, retention_number)
        errors.extend(cleanup_errors)
        return errors

    @type_check
    def delete_snapshots(self, snapshot_name: str) -> list:
        """
        Delete all snapshots matching a specific name.

        Parameters:
        - snapshot_name (str): The name of the snapshot to delete.

        Returns:
        - list: A list of error messages, if any.
        """
        errors = []
        matching_snapshots = [snap for snap in self.cache.snapshots if snap.endswith(f"@{snapshot_name}")]
        for snapshot in matching_snapshots:
            delete_command = f"/sbin/zfs destroy \"{snapshot}\""
            delete_result = run_command(delete_command)
            if delete_result.is_success():
                self.cache.remove_snapshot(snapshot)
                self.logger.debug(f"Deleted snapshot: {snapshot}")
            else:
                error_msg = f"Failed to delete snapshot {snapshot}: {delete_result.get_error()}"
                self.logger.error(error_msg)
                errors.append(error_msg)
        return errors

    @type_check
    def rollback_persistent_volume(self, snapshot_name: str, pv_file: Path) -> dict:
        """
        Restore a PV from a backup YAML file and rollback to a specified snapshot.

        Parameters:
        - snapshot_name (str): Name of the snapshot to rollback to.
        - pv_file (Path): Path to the PV file.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        try:
            with pv_file.open('r') as file:
                pv_data = yaml.safe_load(file)

            pool_name = pv_data['spec']['csi']['volumeAttributes']['openebs.io/poolname']
            volume_handle = pv_data['spec']['csi']['volumeHandle']
            dataset_path = f"{pool_name}/{volume_handle}"

            if dataset_path not in self.cache.datasets:
                message = f"Dataset {dataset_path} does not exist. Cannot restore snapshot."
                self.logger.warning(message)
                result["message"] = message
                return result

            rollback_command = f"/sbin/zfs rollback -r -f \"{dataset_path}@{snapshot_name}\""
            rollback_result = run_command(rollback_command)
            if rollback_result.is_success():
                message = f"Successfully rolled back {dataset_path} to snapshot {snapshot_name}."
                self.logger.debug(message)
                result["success"] = True
                result["message"] = message
            else:
                message = f"Failed to rollback {dataset_path} to snapshot {snapshot_name}: {rollback_result.get_error()}"
                self.logger.error(message)
                result["message"] = message
        except Exception as e:
            message = f"Failed to process PV file {pv_file}: {e}"
            self.logger.error(message, exc_info=True)
            result["message"] = message

        return result

    @type_check
    def list_snapshots(self) -> list:
        """
        List all cached ZFS snapshots.

        Returns:
        - list: A list of all snapshot names.
        """
        snapshots = list(self.cache.snapshots)
        self.logger.debug(f"Listing all snapshots: {snapshots}")
        return snapshots

    @type_check
    def rollback_all_snapshots(self, snapshot_name: str, dataset_path: str) -> None:
        """
        Rollback all snapshots under a given path recursively that match the snapshot name.

        Parameters:
        - snapshot_name (str): The name of the snapshot to rollback to.
        - dataset_path (str): The path of the dataset to rollback snapshots for.
        """
        if dataset_path not in self.cache.datasets:
            self.logger.error(f"Dataset {dataset_path} does not exist. Cannot rollback snapshots.")
            return

        try:
            all_snapshots = [snap for snap in self.cache.snapshots if snap.startswith(dataset_path)]
            matching_snapshots = [snap for snap in all_snapshots if snap.endswith(f"@{snapshot_name}")]
            for snapshot in matching_snapshots:
                rollback_command = f"/sbin/zfs rollback -r -f \"{snapshot}\""
                rollback_result = run_command(rollback_command)
                if rollback_result.is_success():
                    self.logger.debug(f"Successfully rolled back {snapshot}.")
                else:
                    self.logger.error(f"Failed to rollback {snapshot}: {rollback_result.get_error()}")
        except Exception as e:
            self.logger.error(f"Failed to rollback snapshots for {dataset_path}: {e}", exc_info=True)
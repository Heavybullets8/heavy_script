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
    def create_snapshots(self, snapshot_name, dataset_paths: list, retention_number: int) -> dict:
        """
        Create snapshots for specified ZFS datasets and cleanup old snapshots.

        Parameters:
        - snapshot_name (str): Name of the snapshot.
        - dataset_paths (list): List of paths to create snapshots for.
        - retention_number (int): Number of recent snapshots to retain.

        Returns:
        - dict: Result containing status, messages, and list of created snapshots.
        """
        result = {
            "success": False,
            "message": "",
            "errors": [],
            "snapshots": []
        }

        for path in dataset_paths:
            if path not in self.cache.datasets:
                error_msg = f"Dataset {path} does not exist."
                self.logger.error(error_msg)
                result["errors"].append(error_msg)
                continue

            snapshot_full_name = f"{path}@{snapshot_name}"
            command = f"/sbin/zfs snapshot \"{snapshot_full_name}\""
            snapshot_result = run_command(command)
            if snapshot_result.is_success():
                self.cache.add_snapshot(snapshot_full_name)
                self.logger.debug(f"Created snapshot: {snapshot_full_name}")
                result["snapshots"].append(snapshot_full_name)
            else:
                error_msg = f"Failed to create snapshot for {snapshot_full_name}: {snapshot_result.get_error()}"
                self.logger.error(error_msg)
                result["errors"].append(error_msg)
        
        cleanup_errors = self._cleanup_snapshots(dataset_paths, retention_number)
        result["errors"].extend(cleanup_errors)

        if not result["errors"]:
            result["success"] = True
            result["message"] = "All snapshots created and cleaned up successfully."
        else:
            result["message"] = "Some errors occurred during snapshot creation or cleanup."

        return result

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
    def rollback_snapshots(self, snapshots: list) -> dict:
        """
        Rollback multiple snapshots.

        Parameters:
        - snapshots (list): List of snapshots to rollback.

        Returns:
        - dict: Result containing status, messages, and list of rolled back snapshots.
        """
        result = {
            "success": True,
            "messages": [],
            "rolled_back_snapshots": []
        }

        for snapshot in snapshots:
            dataset_path, snapshot_name = snapshot.split('@', 1)
            if dataset_path not in self.cache.datasets:
                message = f"Dataset {dataset_path} does not exist. Cannot restore snapshot."
                self.logger.warning(message)
                result["messages"].append(message)
                result["success"] = False
                continue

            rollback_command = f"/sbin/zfs rollback -r -f \"{snapshot}\""
            rollback_result = run_command(rollback_command)
            if rollback_result.is_success():
                message = f"Successfully rolled back {dataset_path} to snapshot {snapshot_name}."
                self.logger.debug(message)
                result["rolled_back_snapshots"].append({
                    "dataset": dataset_path,
                    "snapshot": snapshot_name
                })
                result["messages"].append(message)
            else:
                message = f"Failed to rollback {dataset_path} to snapshot {snapshot_name}: {rollback_result.get_error()}"
                self.logger.error(message)
                result["messages"].append(message)
                result["success"] = False

        return result

    @type_check
    def list_snapshots(self) -> list:
        """
        List all cached ZFS snapshots.

        Returns:
        - list: A list of all snapshot names.
        """
        snapshots = list(self.cache.snapshots)
        return snapshots

    @type_check
    def snapshot_exists(self, snapshot_name: str) -> bool:
        """
        Check if a snapshot exists in the cache.

        Parameters:
        - snapshot_name (str): The name of the snapshot to check.

        Returns:
        - bool: True if the snapshot exists, False otherwise.
        """
        return snapshot_name in self.cache.snapshots

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

    @type_check
    def zfs_send(self, source: str, destination: Path, compress: bool = False) -> dict:
        """
        Send a ZFS snapshot to a destination file, with optional gzip compression.

        Parameters:
        - source (str): The source ZFS snapshot to send.
        - destination (Path): The destination file to send the snapshot to.
        - compress (bool): Whether to use gzip compression. Default is False.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        try:
            if compress:
                command = f"/sbin/zfs send \"{source}\" | gzip > \"{destination}\""
            else:
                command = f"/sbin/zfs send \"{source}\" > \"{destination}\""

            send_result = run_command(command)
            if send_result.is_success():
                self.logger.debug(f"Successfully sent snapshot {source} to {destination}")
                result["success"] = True
                result["message"] = f"Successfully sent snapshot {source} to {destination}"
            else:
                result["message"] = f"Failed to send snapshot {source}: {send_result.get_error()}"
                self.logger.error(result["message"])
        except Exception as e:
            result["message"] = f"Exception occurred while sending snapshot {source}: {e}"
            self.logger.error(result["message"], exc_info=True)

        return result

    @type_check
    def zfs_receive(self, snapshot_file: Path, dataset_path: str, decompress: bool = False) -> dict:
        """
        Receive a ZFS snapshot from a file and restore it to the specified dataset path.

        Parameters:
        - snapshot_file (Path): The path to the snapshot file.
        - dataset_path (str): The ZFS dataset path to restore to.
        - decompress (bool): Whether the snapshot file is gzip compressed. Default is False.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        try:
            all_snapshots = self.list_snapshots()
            dataset_snapshots = [snap for snap in all_snapshots if snap.startswith(f"{dataset_path}@")]

            for snapshot in dataset_snapshots:
                destroy_command = f'/sbin/zfs destroy "{snapshot}"'
                destroy_result = run_command(destroy_command)
                if destroy_result.is_success():
                    self.cache.remove_snapshot(snapshot)
                    self.logger.debug(f"Deleted snapshot: {snapshot}")
                else:
                    result["message"] = f"Failed to destroy existing snapshot {snapshot}: {destroy_result.get_error()}"
                    self.logger.error(result["message"])
                    return result

            receive_command = f'/sbin/zfs recv -F "{dataset_path}"'
            if decompress:
                command = f'gunzip < "{snapshot_file}" | {receive_command}'
            else:
                command = f'cat "{snapshot_file}" | {receive_command}'
            
            self.logger.debug(f"Executing command: {command}")
            receive_result = run_command(command)
            if receive_result.is_success():
                result["success"] = True
                result["message"] = f"Successfully restored snapshot from {snapshot_file} to {dataset_path}"
            else:
                result["message"] = receive_result.get_error()
        except Exception as e:
            result["message"] = f"Exception occurred while restoring snapshot from {snapshot_file}: {e}"
            self.logger.error(result["message"], exc_info=True)

        return result

import subprocess
from pathlib import Path

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
    def create_snapshot(self, snapshot_name: str, dataset: str) -> dict:
        """
        Create a single ZFS snapshot for the specified dataset.

        Parameters:
        - snapshot_name (str): Name of the snapshot.
        - dataset (str): Dataset to create the snapshot for.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        if dataset not in self.cache.datasets:
            result["message"] = f"Dataset {dataset} does not exist."
            self.logger.error(result["message"])
            return result

        snapshot_full_name = f"{dataset}@{snapshot_name}"
        command = f"/sbin/zfs snapshot \"{snapshot_full_name}\""
        snapshot_result = run_command(command)
        if snapshot_result.is_success():
            refer_size = self.get_snapshot_refer_size(snapshot_full_name)
            self.cache.add_snapshot(snapshot_full_name, refer_size)
            self.logger.debug(f"Created snapshot: {snapshot_full_name} with refer size: {refer_size}")
            result["success"] = True
            result["message"] = f"Snapshot {snapshot_full_name} created successfully."
        else:
            result["message"] = f"Failed to create snapshot for {snapshot_full_name}: {snapshot_result.get_error()}"
            self.logger.error(result["message"])

        return result

    @type_check
    def get_snapshot_refer_size(self, snapshot: str) -> int:
        """
        Get the refer size of a ZFS snapshot.

        Parameters:
        - snapshot (str): The name of the snapshot.

        Returns:
        - int: The refer size of the snapshot in bytes.
        """
        try:
            result = run_command(f"zfs list -H -o refer \"{snapshot}\"")
            if result.is_success():
                size_str = result.get_output()
                size = self._convert_size_to_bytes(size_str)
                return size
            else:
                self.logger.error(f"Failed to get refer size for snapshot {snapshot}: {result.get_error()}")
                return 0
        except Exception as e:
            self.logger.error(f"Exception occurred while getting refer size for snapshot {snapshot}: {e}")
            return 0

    @type_check
    def _convert_size_to_bytes(self, size_str):
        size_units = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
        if size_str[-1] in size_units:
            return int(float(size_str[:-1]) * size_units[size_str[-1]])
        else:
            return int(size_str)

    @type_check
    def delete_snapshot(self, snapshot: str) -> dict:
        """
        Delete a single ZFS snapshot.

        Parameters:
        - snapshot (str): The name of the snapshot to delete.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        delete_command = f"/sbin/zfs destroy \"{snapshot}\""
        delete_result = run_command(delete_command)
        if delete_result.is_success():
            self.cache.remove_snapshot(snapshot)
            self.logger.debug(f"Deleted snapshot: {snapshot}")
            result["success"] = True
            result["message"] = f"Snapshot {snapshot} deleted successfully."
        else:
            result["message"] = f"Failed to delete snapshot {snapshot}: {delete_result.get_error()}"
            self.logger.error(result["message"])

        return result

    @type_check
    def rollback_snapshot(self, snapshot: str, recursive: bool = False, force: bool = False) -> dict:
        """
        Rollback a single ZFS snapshot.

        Parameters:
        - snapshot (str): The name of the snapshot to rollback.
        - recursive (bool): Whether to rollback recursively. Default is False.
        - force (bool): Whether to force the rollback. Default is False.

        Returns:
        - dict: Result containing status and message.
        """
        result = {
            "success": False,
            "message": ""
        }

        dataset_path, snapshot_name = snapshot.split('@', 1)
        if dataset_path not in self.cache.datasets:
            result["message"] = f"Dataset {dataset_path} does not exist. Cannot restore snapshot."
            self.logger.warning(result["message"])
            return result

        rollback_command = f"/sbin/zfs rollback"
        if recursive:
            rollback_command += " -r"
        if force:
            rollback_command += " -f"
        rollback_command += f" \"{snapshot}\""
        
        rollback_result = run_command(rollback_command)
        if rollback_result.is_success():
            result["success"] = True
            result["message"] = f"Successfully rolled back {dataset_path} to snapshot {snapshot_name}."
            self.logger.debug(result["message"])
        else:
            result["message"] = f"Failed to rollback {dataset_path} to snapshot {snapshot_name}: {rollback_result.get_error()}"
            self.logger.error(result["message"])

        return result

    @type_check
    def list_snapshots(self) -> list:
        """
        List all cached ZFS snapshots.

        Returns:
        - list: A list of all snapshot names.
        """
        snapshots = list(self.cache.snapshots.keys())
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
    def rollback_all_snapshots(self, snapshot_name: str, dataset_path: str, recursive: bool = False, force: bool = False) -> None:
        """
        Rollback all snapshots under a given path recursively that match the snapshot name.

        Parameters:
        - snapshot_name (str): The name of the snapshot to rollback to.
        - dataset_path (str): The path of the dataset to rollback snapshots for.
        - recursive (bool): Whether to rollback recursively. Default is False.
        - force (bool): Whether to force the rollback. Default is False.
        """
        if dataset_path not in self.cache.datasets:
            self.logger.error(f"Dataset {dataset_path} does not exist. Cannot rollback snapshots.")
            return

        try:
            all_snapshots = [snap for snap in self.cache.snapshots if snap.startswith(dataset_path)]
            matching_snapshots = [snap for snap in all_snapshots if snap.endswith(f"@{snapshot_name}")]
            for snapshot in matching_snapshots:
                self.rollback_snapshot(snapshot, recursive, force)
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

            delete_errors = []
            for snapshot in dataset_snapshots:
                delete_result = self.delete_snapshot(snapshot)
                if not delete_result["success"]:
                    delete_errors.append(delete_result["message"])

            if delete_errors:
                result["message"] = f"Failed to destroy existing snapshots: {delete_errors}"
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

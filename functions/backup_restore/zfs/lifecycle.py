from zfs.cache import ZFSCache
from utils.shell import run_command
from utils.type_check import type_check
from utils.logger import get_logger

class ZFSLifecycleManager:
    """
    Class responsible for lifecycle operations of ZFS datasets, such as checking existence, creating, and deleting datasets.
    """

    def __init__(self):
        self.logger = get_logger()
        self.cache = ZFSCache()

    @type_check
    def dataset_exists(self, dataset: str) -> bool:
        """
        Check if a dataset exists.

        Parameters:
        - dataset (str): The name of the dataset to check.

        Returns:
        - bool: True if the dataset exists, False otherwise.
        """
        exists = dataset in self.cache.datasets
        self.logger.debug(f"Dataset \"{dataset}\" exists: {exists}")
        return exists

    @type_check
    def create_dataset(self, dataset: str, options: dict = None) -> bool:
        """
        Create a ZFS dataset, including any parent datasets.

        Parameters:
        - dataset (str): The name of the dataset to create.
        - options (dict): Additional options for creating the dataset.

        Returns:
        - bool: True if the dataset was successfully created, False otherwise.
        """
        if self.dataset_exists(dataset):
            self.logger.warning(f"Dataset \"{dataset}\" already exists. Cannot create.")
            return False

        options = options or {}
        command = f"/sbin/zfs create -p"
        for key, value in options.items():
            command += f" -o {key}={value}"
        command += f" \"{dataset}\""
        result = run_command(command, suppress_output=True)

        if result.is_success():
            self.cache.add_dataset(dataset)
            self.logger.debug(f"Dataset \"{dataset}\" created successfully.")
            return True
        else:
            self.logger.error(f"Failed to create dataset \"{dataset}\": {result.get_error()}")
            return False

    @type_check
    def delete_dataset(self, dataset: str) -> bool:
        """
        Delete a ZFS dataset, including all its snapshots.

        Parameters:
        - dataset (str): The name of the dataset to delete.

        Returns:
        - bool: True if the dataset was successfully deleted, False otherwise.
        """
        if not self.dataset_exists(dataset):
            self.logger.warning(f"Dataset \"{dataset}\" does not exist. Cannot delete.")
            return False

        # Delete all associated snapshots first
        snapshots_to_delete = self.cache.get_snapshots_for_dataset(dataset)
        for snapshot in snapshots_to_delete:
            command = f"/sbin/zfs destroy \"{snapshot}\""
            result = run_command(command, suppress_output=True)
            if result.is_success():
                self.cache.remove_snapshot(snapshot)
                self.logger.debug(f"Snapshot \"{snapshot}\" deleted successfully.")
            else:
                self.logger.error(f"Failed to delete snapshot \"{snapshot}\": {result.get_error()}")
                return False

        # Delete the dataset itself
        command = f"/sbin/zfs destroy -r \"{dataset}\""
        result = run_command(command, suppress_output=True)
        if result.is_success():
            self.cache.remove_dataset(dataset)
            self.logger.debug(f"Dataset \"{dataset}\" deleted successfully.")
            return True
        else:
            self.logger.error(f"Failed to delete dataset \"{dataset}\": {result.get_error()}")
            return False

    @property
    def datasets(self) -> list:
        """
        Property to get the current list of cached ZFS datasets.

        Returns:
        - list: A list of all dataset names.
        """
        datasets = list(self.cache.datasets)
        self.logger.debug(f"Listing all datasets: {datasets}")
        return datasets

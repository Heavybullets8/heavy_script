import threading
from utils.shell import run_command
from utils.logger import get_logger
from utils.type_check import type_check

class ZFSCache:
    """
    Singleton class responsible for caching and providing access to ZFS datasets and snapshots.
    Ensures thread safety and updates the cache state across all instances.
    """

    _instance = None
    _lock = threading.Lock()
    _datasets = set()
    _snapshots = {}

    def __new__(cls):
        if not cls._instance:
            with cls._lock:
                if not cls._instance:
                    cls._instance = super(ZFSCache, cls).__new__(cls)
                    cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """
        Initialize the cache by loading datasets and snapshots.
        """
        self.logger = get_logger()
        self.logger.debug("Initializing ZFSCache...")
        self.hard_refresh()

    def _load_datasets(self) -> set:
        """
        Load all ZFS datasets.

        Returns:
            set: A set of all ZFS datasets.
        """
        command = "/sbin/zfs list -H -o name"
        result = run_command(command, suppress_output=True)
        if result.is_success():
            datasets = set(result.get_output().split('\n'))
            self.logger.debug(f"Loaded {len(datasets)} datasets.")
            return datasets
        else:
            self.logger.error("Failed to load datasets.")
            return set()

    def _load_snapshots(self) -> dict:
        """
        Load all ZFS snapshots and their refer sizes.

        Returns:
            dict: A dictionary of all ZFS snapshots with their details.
        """
        command = "/sbin/zfs list -H -t snapshot -o name,refer"
        result = run_command(command, suppress_output=True)
        if result.is_success():
            snapshots = {}
            for line in result.get_output().split('\n'):
                if line:
                    parts = line.split()
                    snapshot_name = parts[0]
                    refer_size = self._convert_size_to_bytes(parts[1])
                    snapshots[snapshot_name] = {"refer": refer_size}
            self.logger.debug(f"Loaded {len(snapshots)} snapshots.")
            return snapshots
        else:
            self.logger.error("Failed to load snapshots.")
            return {}

    def _convert_size_to_bytes(self, size_str):
        size_units = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
        try:
            if size_str[-1] in size_units:
                return int(float(size_str[:-1]) * size_units[size_str[-1]])
            else:
                return int(size_str)
        except ValueError:
            self.logger.error(f"Invalid size string: {size_str}")
            return 0

    def hard_refresh(self):
        """
        Perform a hard refresh by reloading all datasets and snapshots.
        """
        ZFSCache._datasets = self._load_datasets()
        ZFSCache._snapshots = self._load_snapshots()

    def get_snapshots_for_dataset(self, dataset: str) -> dict:
        """
        Get all snapshots associated with a specific dataset.

        Parameters:
            dataset (str): The name of the dataset.

        Returns:
            dict: A dictionary of snapshots associated with the dataset.
        """
        with self._lock:
            return {snap: details for snap, details in ZFSCache._snapshots.items() if snap.startswith(dataset + '@')}

    @property
    def datasets(self) -> set:
        """
        Get the current set of datasets.

        Returns:
            set: The current set of datasets.
        """
        with self._lock:
            return ZFSCache._datasets

    @datasets.setter
    def datasets(self, value: set):
        """
        Set the current set of datasets.

        Parameters:
            value (set): The new set of datasets.
        """
        with self._lock:
            ZFSCache._datasets = value

    @property
    def snapshots(self) -> dict:
        """
        Get the current set of snapshots.

        Returns:
            dict: The current set of snapshots.
        """
        with self._lock:
            return ZFSCache._snapshots

    @snapshots.setter
    def snapshots(self, value: dict):
        """
        Set the current set of snapshots.

        Parameters:
            value (dict): The new set of snapshots.
        """
        with self._lock:
            ZFSCache._snapshots = value

    @type_check
    def add_dataset(self, dataset: str):
        """
        Add a dataset to the cache.

        Parameters:
            dataset (str): The dataset to add.
        """
        with self._lock:
            ZFSCache._datasets.add(dataset)
            self.logger.debug(f"Added dataset: {dataset}")

    @type_check
    def remove_dataset(self, dataset: str):
        """
        Remove a dataset from the cache.

        Parameters:
            dataset (str): The dataset to remove.
        """
        with self._lock:
            ZFSCache._datasets.discard(dataset)
            self.logger.debug(f"Removed dataset: {dataset}")

    @type_check
    def add_snapshot(self, snapshot: str, refer_size: int):
        """
        Add a snapshot to the cache.

        Parameters:
            snapshot (str): The snapshot to add.
            refer_size (int): The refer size of the snapshot.
        """
        with self._lock:
            ZFSCache._snapshots[snapshot] = {"refer": refer_size}
            self.logger.debug(f"Added snapshot: {snapshot} with refer size: {refer_size}")

    @type_check
    def remove_snapshot(self, snapshot: str):
        """
        Remove a snapshot from the cache.

        Parameters:
            snapshot (str): The snapshot to remove.
        """
        with self._lock:
            if snapshot in ZFSCache._snapshots:
                del ZFSCache._snapshots[snapshot]
                self.logger.debug(f"Removed snapshot: {snapshot}")
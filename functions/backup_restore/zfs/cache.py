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
    _snapshots = set()

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

    def _load_snapshots(self) -> set:
        """
        Load all ZFS snapshots.

        Returns:
            set: A set of all ZFS snapshots.
        """
        command = "/sbin/zfs list -H -t snapshot -o name"
        result = run_command(command, suppress_output=True)
        if result.is_success():
            snapshots = set(result.get_output().split('\n'))
            self.logger.debug(f"Loaded {len(snapshots)} snapshots.")
            return snapshots
        else:
            self.logger.error("Failed to load snapshots.")
            return set()

    def hard_refresh(self):
        """
        Perform a hard refresh by reloading all datasets and snapshots.
        """
        ZFSCache._datasets = self._load_datasets()
        ZFSCache._snapshots = self._load_snapshots()

    def get_snapshots_for_dataset(self, dataset: str) -> set:
        """
        Get all snapshots associated with a specific dataset.

        Parameters:
            dataset (str): The name of the dataset.

        Returns:
            set: A set of snapshots associated with the dataset.
        """
        with self._lock:
            return {snap for snap in ZFSCache._snapshots if snap.startswith(dataset + '@')}

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
    def snapshots(self) -> set:
        """
        Get the current set of snapshots.

        Returns:
            set: The current set of snapshots.
        """
        with self._lock:
            return ZFSCache._snapshots

    @snapshots.setter
    def snapshots(self, value: set):
        """
        Set the current set of snapshots.

        Parameters:
            value (set): The new set of snapshots.
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
    def add_snapshot(self, snapshot: str):
        """
        Add a snapshot to the cache.

        Parameters:
            snapshot (str): The snapshot to add.
        """
        with self._lock:
            ZFSCache._snapshots.add(snapshot)
            self.logger.debug(f"Added snapshot: {snapshot}")

    @type_check
    def remove_snapshot(self, snapshot: str):
        """
        Remove a snapshot from the cache.

        Parameters:
            snapshot (str): The snapshot to remove.
        """
        with self._lock:
            ZFSCache._snapshots.discard(snapshot)
            self.logger.debug(f"Removed snapshot: {snapshot}")

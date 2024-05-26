from kubernetes.client.rest import ApiException
from utils.logger import get_logger
from utils.singletons import KubernetesClientManager
from utils.type_check import type_check

class KubePVCFetcher:
    """
    A class to fetch and manage Persistent Volume Claims (PVCs) and Persistent Volumes (PVs) 
    from a Kubernetes cluster.
    """

    def __init__(self):
        """
        Initialize the KubePVCFetcher class.

        Fetches the PVC data from the Kubernetes cluster and prepares a mapping.
        """
        self.logger = get_logger()
        self.v1_client = KubernetesClientManager.fetch()
        self.logger.debug("Initializing KubePVCFetcher...")
        self.pvc_data = self._fetch_pvc_data()

    def _fetch_pvc_data(self) -> dict:
        """
        Fetch all PVCs and PVs data and prepare a mapping, including ZFS volume details.

        Returns:
            dict: A dictionary mapping volume names to PVC details.
        """
        self.logger.debug("Fetching all PVCs and PVs data...")
        pvc_mapping = {}
        try:
            pvcs = self.v1_client.list_persistent_volume_claim_for_all_namespaces()
            pvs = {pv.metadata.name: pv for pv in self.v1_client.list_persistent_volume().items}

            for pvc in pvcs.items:
                pvc_mapping[pvc.spec.volume_name] = self._extract_pvc_info(pvc, pvs)
                self.logger.debug(f"Added PVC info for volume: {pvc.spec.volume_name}")

        except ApiException as e:
            self.logger.error(f"Failed to fetch PVC data: {e}", exc_info=True)
            raise
        return pvc_mapping

    def _extract_pvc_info(self, pvc, pvs) -> dict:
        """
        Helper function to extract PVC information.

        Parameters:
            pvc: The PVC object.
            pvs: Dictionary of PV objects.

        Returns:
            dict: A dictionary containing extracted PVC information.
        """
        volume_name = pvc.spec.volume_name
        pv_detail = pvs.get(volume_name, None)

        if pv_detail and pv_detail.spec and pv_detail.spec.csi:
            volume_attributes = pv_detail.spec.csi.volume_attributes if pv_detail.spec.csi else {}
            pool_name = volume_attributes.get('openebs.io/poolname', 'Unknown')
            dataset_path = f"{pool_name}/{volume_name}"
        else:
            pool_name = 'Unknown'
            dataset_path = None

        reclaim_policy = pv_detail.spec.persistent_volume_reclaim_policy if pv_detail and pv_detail.spec else 'Unknown'
        pv_storage_class = pv_detail.spec.storage_class_name if pv_detail and pv_detail.spec else 'Unknown'

        pvc_info = {
            'app_name': pvc.metadata.labels.get('release', 'Unknown'),
            'pvc_name': pvc.metadata.name,
            'namespace': pvc.metadata.namespace,
            'dataset_path': dataset_path,
            'storage_request': pvc.spec.resources.requests.get('storage', 'Unknown'),
            'storage_class': pvc.spec.storage_class_name,
            'volume_mode': pvc.spec.volume_mode,
            'phase': pvc.status.phase,
            'reclaim_policy': reclaim_policy,
            'pv_storage_class': pv_storage_class,
            'cnpg': any(owner.kind == 'Cluster' for owner in (pvc.metadata.owner_references or []))
        }
        self.logger.debug(f"Extracted PVC info: {pvc_info}")
        return pvc_info

    @type_check
    def has_pvc(self, app_name: str) -> bool:
        """
        Check if an application has any associated PVCs.

        Parameters:
            app_name (str): The name of the application.

        Returns:
            bool: True if the application has associated PVCs, False otherwise.
        """
        return any(info['app_name'] == app_name for info in self.pvc_data.values())

    @type_check
    def get_volume_paths_by_namespace(self, namespace: str) -> list[str]:
        """
        Get the dataset paths of PVC volumes in a namespace.

        Parameters:
            namespace (str): The namespace to search.

        Returns:
            list[str]: Dataset paths of the PVC volumes.
        """
        return [info['dataset_path'] for info in self.pvc_data.values() if info['namespace'] == namespace]

    @type_check
    def get_pv_names_by_namespace(self, namespace: str) -> list[str]:
        """
        Get the names of PVs in a namespace.

        Parameters:
            namespace (str): The namespace to search.

        Returns:
            list[str]: Names of the PVs.
        """
        return [name for name, info in self.pvc_data.items() if info['namespace'] == namespace]

    @type_check
    def get_pvc_name_by_volume_name(self, volume_name: str) -> str:
        """
        Get the name of the PVC associated with a volume.

        Parameters:
            volume_name (str): The name of the volume.

        Returns:
            str: The name of the PVC, or 'Unknown' if not found.
        """
        return self.pvc_data.get(volume_name, {}).get('pvc_name', 'Unknown')

    @type_check
    def is_cnpg(self, volume_name: str) -> bool:
        """
        Check if a volume is associated with a CNPG application.

        Parameters:
            volume_name (str): The name of the volume.

        Returns:
            bool: True if the volume is associated with a CNPG application, False otherwise.
        """
        return self.pvc_data.get(volume_name, {}).get('cnpg', False)
    
    @type_check
    def get_pvs_by_namespace(self, namespace: str) -> dict:
        """
        Get all Persistent Volumes (PVs) associated with PVCs in a specified namespace.

        Parameters:
            namespace (str): The namespace to search for PVs.

        Returns:
            dict: A dictionary mapping volume names to PV details.
        """
        self.logger.debug(f"Fetching PVs for namespace: {namespace}")
        pv_mapping = {}
        try:
            pvs = self.v1_client.list_persistent_volume().items
            for pv in pvs:
                for pvc_name, pvc_info in self.pvc_data.items():
                    if pvc_info['namespace'] == namespace and pv.metadata.name == pvc_name:
                        pv_mapping[pv.metadata.name] = pv
                        self.logger.debug(f"Added PV info for volume: {pv.metadata.name}")
        except ApiException as e:
            self.logger.error(f"Failed to fetch PV data: {e}", exc_info=True)
            raise
        return pv_mapping

import logging
import shutil
from pathlib import Path
import yaml
from utils.shell import run_command
from utils.type_check import type_check
from utils.yaml_cleaner import YAMLCleaner
from utils.singletons import MiddlewareClientManager
from pvc.api_fetch import KubePVCFetcher
from utils.logger import Truncator

class KubeBackupResources:
    """
    A class for managing the backup of Kubernetes resources.
    """
    @type_check
    def __init__(self, app_name: str, backup_dir: Path):
        """
        Initialize the KubeBackupResources class.

        Parameters:
        - app_name (str): The name of the application.
        - backup_dir (Path): The directory where backups will be stored.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.truncator = Truncator(max_length=100)
        self.backup_dir = backup_dir
        self.app_name = app_name
        self.namespace = f"ix-{app_name}"
        self.kube_pvc_fetcher = KubePVCFetcher()
        self.middleware = MiddlewareClientManager.fetch()
        self.logger.debug(f"KubeBackupResources initialized for app: {self.app_name}, backup directory: {self.backup_dir}")

    def backup_secrets(self) -> bool:
        """
        Backup all secrets in the given namespace.

        Returns:
            bool: True if the backup is successful, False otherwise.
        """
        self.logger.debug("Starting backup of secrets...")
        try:
            secrets_dir = self.backup_dir / 'secrets'
            secrets_dir.mkdir(parents=True, exist_ok=True)

            secrets = self.middleware.call(
                'k8s.secret.query', [
                    ['type', 'in', ['helm.sh/release.v1', 'Opaque']],
                    ['metadata.namespace', '=', self.namespace]
                ]
            )

            # Truncate secrets for logging
            truncated_secrets = [self.truncator.truncate(secret) for secret in secrets]
            self.logger.debug(f"Fetched secrets: {truncated_secrets}")

            # Filter and sort secrets
            secrets = sorted(
                filter(lambda d: d.get('data') and not self._should_exclude_secret(d), secrets), 
                key=lambda d: d['metadata']['name']
            )

            # Backup each secret to a YAML file
            for secret in secrets:
                secret_yaml = self.middleware.call('k8s.secret.export_to_yaml_internal', secret)
                secret_file = secrets_dir / f"{secret['metadata']['name']}.yaml"
                with open(secret_file, 'w') as f:
                    f.write(secret_yaml)
                    self.logger.debug(f"Secret {secret['metadata']['name']} backed up.")

            self.logger.debug("Secrets backed up successfully.")
            return True
        except Exception as e:
            self.logger.error(f"Error backing up secrets: {e}", exc_info=True)
            return False

    def _should_exclude_secret(self, secret) -> bool:
        """
        Determine if a secret should be excluded from the backup.

        Parameters:
            secret (dict): The secret to check.

        Returns:
            bool: True if the secret should be excluded, False otherwise.
        """
        owner_references = secret.get('metadata', {}).get('ownerReferences', [])
        for owner in owner_references:
            if owner.get('apiVersion') == 'postgresql.cnpg.io/v1':
                self.logger.debug(f"Excluding secret {secret['metadata']['name']} due to owner reference.")
                return True
        return False

    def backup_pvcs(self) -> list:
        """
        Backup all PVC-related volumes in the given namespace.

        Returns:
            list: A list of error messages if any errors occur during backup.
        """
        self.logger.debug("Starting backup of PVCs...")
        errors = []
        pvs = self.kube_pvc_fetcher.get_pv_names_by_namespace(self.namespace)

        if not pvs:
            self.logger.debug("No PVCs found for backup.")
            return ["No PVCs found for backup."]

        pv_zfs_dir = self.backup_dir / 'pv_zfs_volumes'
        pv_zfs_dir.mkdir(parents=True, exist_ok=True)

        yaml_cleaner = YAMLCleaner()
        for pv in pvs:
            try:
                if self.kube_pvc_fetcher.is_cnpg(pv):
                    self.logger.debug(f"Skipping CNPG volume: {pv}")
                    continue

                pvc_name = self.kube_pvc_fetcher.get_pvc_name_by_volume_name(pv)
                self.logger.debug(f"Backing up volume: {pv} from PVC: {pvc_name}")

                pv_output_result = run_command(f"k3s kubectl get pv {pv} -o yaml")
                if pv_output_result.is_success():
                    cleaned_data = yaml_cleaner.clean_yaml(pv_output_result.get_output())
                    self._write_yaml_backup(cleaned_data, pv_zfs_dir / f"{pvc_name}-pv.yaml")
                    self.logger.debug(f"{pv} data for {pvc_name} backed up successfully.")
                else:
                    error_msg = f"Error retrieving PV data for {pv}: {pv_output_result.get_error()}"
                    self.logger.error(error_msg)
                    errors.append(error_msg)

                zfs_output_result = run_command(f"k3s kubectl get zfsvolumes -A --field-selector metadata.name={pv} -o yaml")
                if zfs_output_result.is_success():
                    zfs_volume_data = yaml.safe_load(zfs_output_result.get_output())
                    if zfs_volume_data['items']:
                        zfs_volume_item = zfs_volume_data['items'][0]
                        zfs_volume_yaml = yaml.dump(zfs_volume_item)
                        self._write_yaml_backup(zfs_volume_yaml, pv_zfs_dir / f"{pvc_name}-zfsvolume.yaml")
                    else:
                        error_msg = f"No ZFS volume found for PV {pv}."
                        self.logger.error(error_msg)
                        errors.append(error_msg)
                else:
                    error_msg = f"Error retrieving ZFS volume data for {pv}: {zfs_output_result.get_error()}"
                    self.logger.error(error_msg)
                    errors.append(error_msg)
            except KeyError as e:
                error_msg = f"Error processing PV {pv}: {e}"
                self.logger.error(error_msg)
                errors.append(error_msg)

        return errors

    def backup_namespace(self) -> bool:
        """
        Backup the namespace configuration.

        Returns:
            bool: True if the backup is successful, False otherwise.
        """
        self.logger.debug(f"Starting backup of namespace: {self.namespace}")
        namespace_result = run_command(f"k3s kubectl get namespace {self.namespace} -o yaml")
        if namespace_result.is_success():
            yaml_cleaner = YAMLCleaner()  # Use default removals
            cleaned_data = yaml_cleaner.clean_yaml(namespace_result.get_output())
            namespace_dir = self.backup_dir / 'namespace'
            namespace_dir.mkdir(parents=True, exist_ok=True)
            self._write_yaml_backup(cleaned_data, namespace_dir / "namespace.yaml")
            self.logger.debug("Namespace configuration backed up successfully.")
            return True
        else:
            self.logger.error(f"Error retrieving namespace configuration: {namespace_result.get_error()}")
            return False

    def _write_yaml_backup(self, yaml_data: str, file_path: Path):
        """
        Write cleaned and filtered YAML data to a file.

        Parameters:
            yaml_data (str): The YAML data to write.
            file_path (Path): The file path to write the data to.
        """
        file_path.parent.mkdir(parents=True, exist_ok=True)
        self.logger.debug(f"Writing YAML backup to {file_path}")
        with open(file_path, 'w') as file:
            file.write(yaml_data)
        self.logger.debug(f"Written YAML backup to {file_path}")

    @type_check
    def backup_crd(self, crd_dir: Path) -> bool:
        """
        Backup all CRDs in the given directory.

        Parameters:
            crd_dir (Path): The directory containing CRD files.

        Returns:
            bool: True if all CRDs are backed up successfully, False otherwise.
        """
        self.logger.debug(f"Starting backup of CRDs from directory: {crd_dir}")
        success = True
        crd_backup_dir = self.backup_dir / 'crds'
        crd_backup_dir.mkdir(parents=True, exist_ok=True)
        
        for file in crd_dir.glob('*.yaml'):
            destination = crd_backup_dir / file.stem
            try:
                shutil.copy(file, destination)
                self.logger.debug(f"Backed up CRD from {file} to {destination}")
            except Exception as e:
                self.logger.error(f"Failed to backup CRD {file} to {destination}: {e}", exc_info=True)
                success = False
        return success

import tempfile
from pathlib import Path
import yaml
from typing import List
from utils.logger import get_logger
from utils.type_check import type_check
from utils.shell import run_command
from utils.yaml_cleaner import YAMLCleaner

class KubeRestoreResources:
    """
    Class to restore Kubernetes resources from a backup directory.
    """
    def __init__(self):
        self.logger = get_logger()
        self.yaml_cleaner = YAMLCleaner()
        self.logger.debug(f"KubeRestoreResources initialized")

    @type_check
    def restore_pv_zfs_volumes(self, volume_files: List[Path]) -> list:
        """
        Restore PV and ZFS volumes for the application from its backup directory.

        Parameters:
        - volume_files (List[Path]): List of volume file paths to restore.

        Returns:
        - list: List of files that failed to restore. If everything succeeds, returns an empty list.
        """
        self.logger.debug("Restoring PV and ZFS volumes from provided file list...")
        failures = []
        volume_files = sorted(volume_files, key=lambda f: '-zfsvolume.yaml' in f.name)

        if not volume_files:
            self.logger.warning("No PV or ZFS volume files provided.")
            return ["No PV or ZFS volume files provided"]

        for file in volume_files:
            self.logger.debug(f"Restoring volume from file: {file}")
            try:
                with open(file, 'r') as f:
                    yaml_data = f.read()
                    cleaned_data = self.yaml_cleaner.clean_yaml(yaml_data)
                
                with tempfile.NamedTemporaryFile(delete=True) as temp_file:
                    temp_file.write(cleaned_data.encode())
                    temp_file.flush()
                    temp_file.seek(0)

                    restore_result = run_command(f'k3s kubectl apply -f "{temp_file.name}" --validate=false')
                    if restore_result.is_success():
                        self.logger.debug(f"Restored {file.name}")
                    else:
                        self.logger.error(f"Failed to restore {file.name}: {restore_result.get_error()}")
                        failures.append(file.name)
            except Exception as e:
                self.logger.error(f"Error processing volume file {file}: {e}")
                failures.append(file.name)
        return failures

    @type_check
    def restore_namespace(self, namespace_file: Path) -> bool:
        """
        Restore the namespace configuration from a namespace.yaml file.

        Parameters:
        - namespace_file (Path): Path to the namespace.yaml file to restore.

        Returns:
        - bool: True if the namespace is restored successfully, False otherwise.
        """
        self.logger.debug(f"Restoring namespace from {namespace_file}...")

        try:
            with open(namespace_file, 'r') as f:
                yaml_data = f.read()
                cleaned_data = self.yaml_cleaner.clean_yaml(yaml_data)

            with tempfile.NamedTemporaryFile(delete=True) as temp_file:
                temp_file.write(cleaned_data.encode())
                temp_file.flush()
                temp_file.seek(0)

                restore_result = run_command(f'k3s kubectl apply -f "{temp_file.name}" --validate=false')
                if restore_result.is_success():
                    self.logger.debug(f"Successfully restored namespace from {namespace_file}")
                    return True
                else:
                    self.logger.error(f"Failed to restore namespace from {namespace_file}: {restore_result.get_error()}")
                    return False
        except Exception as e:
            self.logger.error(f"Error processing namespace file {namespace_file}: {e}")
            return False

    @type_check
    def restore_secrets(self, secret_files: List[Path]) -> list:
        """
        Restore secrets for the application from its backup directory.

        Parameters:
        - secret_files (List[Path]): List of secret file paths to restore.

        Returns:
        - list: List of files that failed to restore. If everything succeeds, returns an empty list.
        """
        self.logger.debug("Restoring secrets from provided file list...")
        failures = []

        if not secret_files:
            self.logger.warning("No secret files provided.")
            return []

        for secret_file in secret_files:
            self.logger.debug(f"Restoring secret from file: {secret_file}")
            try:
                with open(secret_file, 'r') as f:
                    secret_body = yaml.safe_load(f)
                    secret_body['metadata'].pop('resourceVersion', None)
                    secret_body['metadata'].pop('uid', None)
                    secret_body['metadata']['annotations'] = secret_body['metadata'].get('annotations', {})
                    secret_body['metadata']['annotations']['kubectl.kubernetes.io/last-applied-configuration'] = yaml.dump(secret_body)
                with open(secret_file, 'w') as f:
                    yaml.dump(secret_body, f)
                restoreResult = run_command(f"k3s kubectl apply -f \"{secret_file}\" --validate=false")
                if restoreResult.is_success():
                    self.logger.debug(f"Restored {secret_file.name}")
                else:
                    self.logger.error(f"Failed to restore {secret_file.name}: {restoreResult.get_error()}")
                    failures.append(secret_file.name)
            except Exception as e:
                self.logger.error(f"Error processing secret file {secret_file}: {e}")
                failures.append(secret_file.name)
        return failures

    @type_check
    def restore_crd(self, crd_files: List[Path]) -> list:
        """
        Restore CRDs for the application from its backup directory.

        Parameters:
        - crd_files (List[Path]): List of CRD file paths to restore.

        Returns:
        - list: List of files that failed to restore. If everything succeeds, returns an empty list.
        """
        self.logger.debug("Restoring CRDs from provided file list...")
        failures = []

        if not crd_files:
            self.logger.warning("No CRD files provided.")
            return []

        for file in crd_files:
            self.logger.debug(f"Restoring CRD from file: {file}")
            restoreResult = run_command(f"k3s kubectl apply -f \"{file}\" --validate=false")
            if restoreResult.is_success():
                self.logger.debug(f"Restored {file.name}")
            else:
                self.logger.error(f"Failed to restore {file.name}: {restoreResult.get_error()}")
                failures.append(file.name)
        return failures
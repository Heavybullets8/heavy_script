import os
import shutil
import logging
from pathlib import Path
from utils.type_check import type_check
from utils.singletons import MiddlewareClientManager
from utils.check_job import check_job_status

class KubeUtils:
    """
    Utility class for managing Kubernetes services and resources.
    """

    def __init__(self):
        """
        Initialize the KubeUtils class.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.middleware = MiddlewareClientManager.fetch()
        self.logger.debug("KubeUtils initialized.")

    def abort_sync_jobs(self):
        """
        Abort all sync jobs that are either in WAITING or RUNNING state.
        """
        self.logger.debug("Aborting all sync jobs...")
        try:
            catalog_sync_jobs = self.middleware.call('core.get_jobs', [
                ['OR', [
                    ['method', '=', 'catalog.sync'], ['method', '=', 'catalog.sync_all'],
                ]],
                ['OR', [['state', '=', 'RUNNING'], ['state', '=', 'WAITING']]]
            ])

            # Handle WAITING jobs
            for sync_job in filter(lambda j: j['state'] == 'WAITING', catalog_sync_jobs):
                try:
                    self.middleware.call('core.job_abort', sync_job['id'])
                    self.logger.debug(f"Aborted job {sync_job['id']} in WAITING state.")
                except Exception as e:
                    self.logger.error(f"Failed to abort job {sync_job['id']}: {e}", exc_info=True)

            # Handle RUNNING jobs
            for sync_job in filter(lambda j: j['state'] == 'RUNNING', catalog_sync_jobs):
                self.logger.debug(f"Waiting for job {sync_job['id']} to complete...")
                if check_job_status(sync_job['id']):
                    self.logger.debug(f"Job {sync_job['id']} has successfully completed.")
                else:
                    self.logger.error(f"Job {sync_job['id']} failed to complete successfully.")
        except Exception as e:
            self.logger.error(f"Failed to abort sync jobs: {e}", exc_info=True)

    def stop_kubernetes_services(self):
        """
        Stop all Kubernetes services.
        """
        self.logger.debug("Stopping Kubernetes services...")
        try:
            self.middleware.call('service.stop', 'kubernetes')
            self.logger.debug("Successfully stopped Kubernetes services.")
        except Exception as e:
            self.logger.error("Failed to stop Kubernetes services.", exc_info=True)
            raise ValueError("Failed to stop Kubernetes services.") from e

    def start_kubernetes_services(self):
        """
        Start all Kubernetes services.
        """
        self.logger.debug("Starting Kubernetes services...")
        try:
            self.middleware.call('service.start', 'kubernetes')
            self.logger.debug("Successfully started Kubernetes services.")
        except Exception as e:
            self.logger.error("Failed to start Kubernetes services.", exc_info=True)
            raise ValueError("Failed to start Kubernetes services.") from e

    def delete_rancher_data(self):
        """
        Delete all Rancher data.
        """
        self.logger.debug("Deleting Rancher data...")
        try:
            shutil.rmtree('/etc/rancher', True)
            self.logger.debug("Successfully deleted Rancher data.")
        except Exception as e:
            self.logger.error("Failed to delete Rancher data.", exc_info=True)
            raise ValueError("Failed to delete Rancher data.") from e

    def reset_kubernetes_cni_config(self):
        """
        Reset the CNI configuration for the Kubernetes service by clearing the cni_config.

        Returns:
            bool: True if the CNI configuration is reset successfully, False otherwise.
        """
        self.logger.debug("Resetting Kubernetes CNI configuration...")
        try:
            # Fetch the current Kubernetes service configuration
            db_config = self.middleware.call('datastore.config', 'services.kubernetes')
            self.logger.debug(f"Fetched Kubernetes config: {db_config}")

            # Reset the CNI configuration
            result = self.middleware.call('datastore.update', 'services.kubernetes', db_config['id'], {'cni_config': {}})
            self.logger.debug(f"Kubernetes CNI config reset successfully: {result}")

            return True
        except Exception as e:
            self.logger.error(f"Failed to reset Kubernetes CNI configuration: {e}", exc_info=True)
            return False
    
    @type_check
    def to_ignore_datasets_on_backup(self, applications_dataset: str):
        """
        Return datasets to ignore during backup.

        Parameters:
            applications_dataset (str): The root dataset under which Kubernetes operates.

        Returns:
            dict: A dictionary of datasets to ignore.
        """
        self.logger.debug(f"Generating list of datasets to ignore during backup for {applications_dataset}...")
        datasets = {
            os.path.join(applications_dataset, ds_name): ds_props
            for ds_name, ds_props in {
                'k3s/kubelet': {'mount': False, 'creation_props': {'mountpoint': 'legacy'}}
            }.items()
        }
        self.logger.debug(f"Datasets to ignore: {datasets}")
        return datasets

    @type_check
    def delete_and_recreate_datasets(self, applications_dataset: str) -> bool:
        """
        Deletes and then recreates ZFS datasets based on Kubernetes configurations, excluding catalogs.

        Parameters:
            applications_dataset (str): The root dataset under which Kubernetes operates.

        Returns:
            bool: True if datasets are deleted and recreated successfully, False otherwise.
        """
        self.logger.debug(f"Deleting and recreating datasets for {applications_dataset}...")
        try:
            # Fetch datasets to manage, excluding 'catalogs'
            fresh_datasets = self.to_ignore_datasets_on_backup(applications_dataset)
            self.logger.debug(f"Datasets to be deleted and recreated: {fresh_datasets}")

            # Delete the datasets
            for dataset in fresh_datasets:
                self.middleware.call('zfs.dataset.delete', dataset, {'force': True, 'recursive': True})
                self.logger.debug(f"Deleted dataset: {dataset}")

            # Recreate the datasets
            for dataset, ds_details in fresh_datasets.items():
                self.middleware.call('zfs.dataset.create', {
                    'name': dataset,
                    'type': 'FILESYSTEM',
                    **({'properties': ds_details['creation_props']} if ds_details.get('creation_props') else {})
                })
                self.logger.debug(f"Recreated dataset: {dataset}")

                # Mount the dataset if specified
                if ds_details.get('mount'):
                    self.middleware.call('zfs.dataset.mount', dataset)
                    self.logger.debug(f"Mounted dataset: {dataset}")

            self.logger.debug("Datasets deleted and recreated successfully.")
            return True
        except Exception as e:
            self.logger.error(f"Error during dataset management: {e}", exc_info=True)
            return False 

    @type_check
    def cleanup_directory(self, directory_path: Path) -> tuple:
        """
        Performs cleanup by deleting all subdirectories within the specified directory path.

        Parameters:
            directory_path (Path): The path of the directory to clean up.

        Returns:
            tuple: (bool, str) - True if cleanup is successful, False otherwise; Message indicating the result.
        """
        self.logger.debug(f"Starting cleanup in: {directory_path}")

        try:
            for name in os.listdir(directory_path):
                dir_path = os.path.join(directory_path, name)
                if os.path.isdir(dir_path):
                    shutil.rmtree(dir_path)
                    self.logger.debug(f"Deleted directory: {dir_path}")
            self.logger.debug(f"Cleanup completed successfully for {directory_path}.")
            return True, "Cleanup completed successfully."
        except FileNotFoundError:
            self.logger.error(f"The directory {directory_path} does not exist.")
            return False, "Directory not found."
        except PermissionError:
            self.logger.error(f"Permission denied when trying to delete directories in {directory_path}.")
            return False, "Permission denied."
        except Exception as e:
            self.logger.error(f"An error occurred during cleanup: {e}", exc_info=True)
            return False, str(e)

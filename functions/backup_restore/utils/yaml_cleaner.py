import logging
import yaml

class YAMLCleaner:
    """
    A class for cleaning YAML data by removing specified global keys, static paths,
    filtering CNPG managed resources, and removing empty containers.
    """

    def __init__(self, global_removals=None, static_removals=None):
        """
        Initialize the YAMLCleaner with optional global and static removal sets.

        Parameters:
            global_removals (set): A set of global keys to remove from the YAML data.
            static_removals (set): A set of specific paths to remove from the YAML data.
        """
        self.logger = logging.getLogger('BackupLogger')
        self.global_removals = global_removals if global_removals is not None else {'uid', 'resourceVersion', 'creationTimestamp', 'status'}
        self.static_removals = static_removals if static_removals is not None else {
            ('spec', 'nodeAffinity'),
            ('metadata', 'labels', 'kubernetes.io/nodename'),
            ('spec', 'csi', 'volumeAttributes', 'storage.kubernetes.io/csiProvisionerIdentity')
        }

    def clean_globals(self, data):
        """
        Remove global keys from all parts of the YAML data.

        Parameters:
            data (dict): The YAML data as a dictionary.
        """
        def recurse(data):
            if isinstance(data, dict):
                keys_to_delete = [key for key in data if key in self.global_removals]
                for key in keys_to_delete:
                    data.pop(key)
                for value in data.values():
                    recurse(value)
            elif isinstance(data, list):
                for item in data:
                    recurse(item)
        recurse(data)

    def clean_statics(self, data):
        """
        Remove keys based on specific paths.

        Parameters:
            data (dict): The YAML data as a dictionary.
        """
        def recurse(data, path=()):
            if isinstance(data, dict):
                for key, value in list(data.items()):
                    new_path = path + (key,)
                    if new_path in self.static_removals:
                        data.pop(key)
                    else:
                        recurse(value, new_path)
            elif isinstance(data, list):
                for item in data:
                    recurse(item, path)
        recurse(data)

    def filter_cnpg_resources(self, data):
        """
        Filter out CNPG managed resources and resources from Kubernetes resources in YAML.

        Parameters:
            data (dict): The YAML data as a dictionary.
        """
        items = data.get('items', [])
        filtered_items = [
            item for item in items if not (
                any(owner.get('kind') == 'Cluster' for owner in item.get('metadata', {}).get('ownerReferences', []))
                or "-cnpg-main-" in item.get('metadata', {}).get('name', "")
            )
        ]
        data['items'] = filtered_items

    def remove_empty_containers(self, data):
        """
        Recursively remove all empty lists and empty dictionaries from the YAML data.

        Parameters:
            data (dict): The YAML data as a dictionary.
        """
        if isinstance(data, dict):
            keys_to_delete = [key for key, value in data.items() if (isinstance(value, (dict, list)) and not value)]
            for key in keys_to_delete:
                data.pop(key)
            for value in data.values():
                self.remove_empty_containers(value)
        elif isinstance(data, list):
            data[:] = [item for item in data if item]
            for item in data:
                self.remove_empty_containers(item)

    def clean_yaml(self, yaml_data):
        """
        Apply all cleaning operations to the YAML data.

        Parameters:
            yaml_data (str): The YAML data as a string.

        Returns:
            str: The cleaned YAML data as a string.
        """
        data = yaml.safe_load(yaml_data)
        self.clean_globals(data)
        self.clean_statics(data)
        self.filter_cnpg_resources(data)
        self.remove_empty_containers(data)
        return yaml.dump(data, default_flow_style=False, sort_keys=False)

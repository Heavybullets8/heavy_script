import configparser
import sys
from pathlib import Path

def update_config(config_file_path):
    config_file_path = Path(config_file_path)
    
    # Read the config file
    config = configparser.ConfigParser(allow_no_value=True)
    config.read(config_file_path)

    # Remove the [databases] section if it exists
    if 'databases' in config:
        config.remove_section('databases')

    # Check if [BACKUP] section exists and has the necessary fields
    backup_section_exists = 'BACKUP' in config
    export_enabled_exists = backup_section_exists and config.has_option('BACKUP', 'export_enabled')
    full_backup_enabled_exists = backup_section_exists and config.has_option('BACKUP', 'full_backup_enabled')
    custom_dataset_location_exists = backup_section_exists and config.has_option('BACKUP', 'custom_dataset_location')

    # If all required fields are present, no need to update
    if export_enabled_exists and full_backup_enabled_exists and custom_dataset_location_exists:
        print(f"{config_file_path} is already up to date.")
        return

    # Add the [BACKUP] section with the specified options if they don't exist
    if not backup_section_exists:
        config.add_section('BACKUP')

    if not export_enabled_exists:
        config.set('BACKUP', 'export_enabled', 'true')
    if not full_backup_enabled_exists:
        config.set('BACKUP', 'full_backup_enabled', 'true')
    if not custom_dataset_location_exists:
        config.set('BACKUP', '# Uncomment the following line to specify a custom dataset location for backups', None)
        config.set('BACKUP', '# custom_dataset_location', '')

    # Write the changes back to the config file
    with config_file_path.open('w') as configfile:
        config.write(configfile, space_around_delimiters=False)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)
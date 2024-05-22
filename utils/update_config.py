import sys
from pathlib import Path
import configparser

def update_config(config_file_path):
    config_file_path = Path(config_file_path)
    # Read the original content preserving comments
    with config_file_path.open('r') as file:
        lines = file.readlines()

    # Create a new config parser object
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

    # Prepare the new content
    new_content = []
    in_databases_section = False
    in_backup_section = False

    for line in lines:
        if line.strip().lower() == '[databases]':
            in_databases_section = True
            continue
        if line.startswith('['):
            if in_databases_section:
                in_databases_section = False
            if line.strip().lower() == '[backup]':
                in_backup_section = True
            else:
                in_backup_section = False
        if not in_databases_section:
            if in_backup_section:
                if not export_enabled_exists and 'export_enabled=' not in line:
                    new_content.append('export_enabled=true\n')
                    export_enabled_exists = True
                if not full_backup_enabled_exists and 'full_backup_enabled=' not in line:
                    new_content.append('full_backup_enabled=true\n')
                    full_backup_enabled_exists = True
                if not custom_dataset_location_exists and 'custom_dataset_location=' not in line:
                    new_content.append('# Uncomment the following line to specify a custom dataset location for backups\n')
                    new_content.append('# custom_dataset_location=\n')
                    custom_dataset_location_exists = True
            new_content.append(line)

    # Ensure the [BACKUP] section is added if it does not exist
    if not backup_section_exists:
        new_content.append('\n[BACKUP]\n')
        if not export_enabled_exists:
            new_content.append('export_enabled=true\n')
        if not full_backup_enabled_exists:
            new_content.append('full_backup_enabled=true\n')
        if not custom_dataset_location_exists:
            new_content.append('# Uncomment the following line to specify a custom dataset location for backups\n')
            new_content.append('# custom_dataset_location=\n')

    # Write the new content back to the config file
    with config_file_path.open('w') as file:
        file.writelines(new_content)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

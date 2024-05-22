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

    # Prepare the new content
    new_content = []
    in_databases_section = False

    for line in lines:
        if line.strip().lower() == '[databases]':
            in_databases_section = True
            continue
        if line.startswith('[') and in_databases_section:
            in_databases_section = False
        if not in_databases_section:
            new_content.append(line)

    # Ensure the [BACKUP] section is added if it does not exist
    if 'BACKUP' not in config:
        new_content.append('\n[BACKUP]\n')
        new_content.append('export_enabled=true\n')
        new_content.append('full_backup_enabled=true\n')
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

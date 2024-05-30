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
    backup_section_exists = False
    in_backup_section = False
    backup_options = {
        'export_enabled': 'export_enabled=true\n',
        'full_backup_enabled': 'full_backup_enabled=true\n',
        'backup_snapshot_streams': 'backup_snapshot_streams=false\n',
        'max_stream_size': (
            '# Maximum size of a backup stream, the default is 10GB, be careful when setting this higher\n'
            '# Especially considering PV\'s for plex, sonarr, radarr, etc. can be quite large\n'
            '# Example: max_stream_size=10GB, max_stream_size=20KB, max_stream_size=1TB\n'
            '# max_stream_size=10GB\n'
        )
    }
    backup_keys = set(backup_options.keys())

    for line in lines:
        # Detect if we are in the [databases] section
        if line.strip().lower() == '[databases]':
            in_databases_section = True
            continue
        if line.startswith('[') and in_databases_section:
            in_databases_section = False
        if in_databases_section:
            continue

        # Detect if we are in the [BACKUP] section
        if line.strip().lower() == '[backup]':
            backup_section_exists = True
            in_backup_section = True
        elif line.startswith('[') and in_backup_section:
            in_backup_section = False

        # Add lines to the new content
        if in_backup_section:
            key = line.split('=')[0].strip()
            if key in backup_keys:
                backup_keys.discard(key)

        new_content.append(line)

    # If the [BACKUP] section exists but is missing some keys, add the missing keys
    if backup_section_exists and backup_keys:
        new_content.append('\n')
        for key in backup_keys:
            new_content.append(backup_options[key])

    # If the [BACKUP] section does not exist, add it
    if not backup_section_exists:
        new_content.append('\n[BACKUP]\n')
        for key in backup_options:
            new_content.append(backup_options[key])

    # Write the new content back to the config file
    with config_file_path.open('w') as file:
        file.writelines(new_content)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

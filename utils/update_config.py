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

        # Add lines to the new content, and check for existing keys in the [BACKUP] section
        if in_backup_section:
            if 'export_enabled' not in config['BACKUP']:
                new_content.append('export_enabled=true\n')
            if 'full_backup_enabled' not in config['BACKUP']:
                new_content.append('full_backup_enabled=true\n')
            if 'backup_snapshot_streams' not in config['BACKUP']:
                new_content.append('backup_snapshot_streams=false\n')
            if 'max_stream_size' not in config['BACKUP']:
                new_content.append('# Maximum size of a backup stream, the default is 10GB, be careful when setting this higher\n')
                new_content.append('# Especially considering PV\'s for plex, sonarr, radarr, etc. can be quite large\n')
                new_content.append('# Example: max_stream_size=10GB, max_stream_size=20KB, max_stream_size=1TB\n')
                new_content.append('# max_stream_size=10GB\n')
        
        new_content.append(line)

    # If the [BACKUP] section does not exist, add it
    if not backup_section_exists:
        new_content.append('\n[BACKUP]\n')
        new_content.append('export_enabled=true\n')
        new_content.append('full_backup_enabled=true\n')
        new_content.append('backup_snapshot_streams=false\n')
        new_content.append('\n## String options ##\n')
        new_content.append('# Uncomment the following line to specify a custom dataset location for backups\n')
        new_content.append('# custom_dataset_location=\n')
        new_content.append('\n# Maximum size of a backup stream, the default is 10GB, be careful when setting this higher\n')
        new_content.append('# Especially considering PV\'s for plex, sonarr, radarr, etc. can be quite large\n')
        new_content.append('# Example: max_stream_size=10GB, max_stream_size=20KB, max_stream_size=1TB\n')
        new_content.append('# max_stream_size=10GB\n')

    # Write the new content back to the config file
    with config_file_path.open('w') as file:
        file.writelines(new_content)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

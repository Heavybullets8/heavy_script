import sys
from pathlib import Path
import configparser

def update_config(config_file_path):
    config_file_path = Path(config_file_path)
    
    # Create a new config parser object with comments allowed
    config = configparser.ConfigParser(allow_no_value=True)
    config.optionxform = str  # Preserve the letter case of keys
    config.read(config_file_path)

    # Remove the [databases] section if it exists
    if 'databases' in config:
        config.remove_section('databases')
    
    # Ensure the [BACKUP] section is added and contains the required options
    if 'BACKUP' not in config:
        config.add_section('BACKUP')

    backup_section = config['BACKUP']

    # Add required options if they do not exist
    if 'export_enabled' not in backup_section:
        backup_section['export_enabled'] = 'true'
    if 'full_backup_enabled' not in backup_section:
        backup_section['full_backup_enabled'] = 'true'
    if 'backup_snapshot_streams' not in backup_section:
        backup_section['backup_snapshot_streams'] = 'false'
    if 'max_stream_size' not in backup_section:
        backup_section['; Maximum size of a backup stream, the default is 10GB, be careful when setting this higher\n'
                        '# Especially considering PV\'s for plex, sonarr, radarr, etc. can be quite large\n'
                        '# Example: max_stream_size=10GB, max_stream_size=20KB, max_stream_size=1TB'] = None
        backup_section['max_stream_size'] = '10GB'

    # Write the updated config back to the file
    with config_file_path.open('w') as file:
        config.write(file, space_around_delimiters=False)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

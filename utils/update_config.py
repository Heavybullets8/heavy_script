import sys
from pathlib import Path
import configparser

def update_config(config_file_path):
    config_file_path = Path(config_file_path)
    default_config_path = Path(__file__).parent / '.default.config.ini'
    
    # Read the original content preserving comments
    with config_file_path.open('r') as file:
        lines = file.readlines()

    # Load the existing config
    config = configparser.ConfigParser(allow_no_value=True)
    config.optionxform = str  # Preserve the letter case of keys
    config.read(config_file_path)

    # Remove the [databases] section if it exists
    if 'databases' in config:
        config.remove_section('databases')

    # Load the default config from .default.config.ini
    default_config_parser = configparser.ConfigParser(allow_no_value=True)
    default_config_parser.optionxform = str  # Preserve the letter case of keys
    default_config_parser.read(default_config_path)

    # Collect lines to write back, excluding [databases] section
    new_lines = []
    in_databases_section = False
    for line in lines:
        if line.strip().lower() == '[databases]':
            in_databases_section = True
            continue
        if line.startswith('[') and in_databases_section:
            in_databases_section = False
        if not in_databases_section:
            new_lines.append(line)

    # Write the collected lines back to the file
    with config_file_path.open('w') as file:
        file.writelines(new_lines)
        
        # Ensure new sections and options are added if missing
        for section in default_config_parser.sections():
            if not config.has_section(section):
                file.write(f'\n[{section}]\n')
            for key, value in default_config_parser.items(section):
                if not config.has_option(section, key):
                    if value is None:
                        file.write(f'{key}\n')
                    else:
                        file.write(f'{key}={value}\n')

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

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
    current_config = configparser.ConfigParser(allow_no_value=True)
    current_config.optionxform = str  # Preserve the letter case of keys
    current_config.read(config_file_path)

    # Load the default config from .default.config.ini
    default_config = configparser.ConfigParser(allow_no_value=True)
    default_config.optionxform = str  # Preserve the letter case of keys
    default_config.read(default_config_path)

    # Remove sections from the current config that are not in the default config
    sections_to_remove = [section for section in current_config.sections() if section not in default_config.sections()]
    for section in sections_to_remove:
        current_config.remove_section(section)

    # Update the existing config with missing sections and options from the default config
    for section in default_config.sections():
        if not current_config.has_section(section):
            current_config.add_section(section)
        for key, value in default_config.items(section):
            if not current_config.has_option(section, key):
                current_config.set(section, key, value)

    # Write the updated config back to the file preserving the original comments
    with config_file_path.open('w') as file:
        in_removed_section = False
        for line in lines:
            if any(line.strip().lower() == f'[{s.lower()}]' for s in sections_to_remove):
                in_removed_section = True
                continue
            if line.startswith('[') and in_removed_section:
                in_removed_section = False
            if not in_removed_section:
                file.write(line)
        
        # Ensure new sections and options are added if missing
        for section in default_config.sections():
            if not any(f'[{section}]' in line for line in lines):
                file.write(f'\n[{section}]\n')
                for key, value in default_config.items(section):
                    if value is None:
                        file.write(f'{key}\n')
                    else:
                        file.write(f'{key}={value}\n')
            else:
                for key, value in default_config.items(section):
                    if not any(key in line for line in lines):
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

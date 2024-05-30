import sys
from pathlib import Path
import configparser

def update_config(config_file_path):
    config_file_path = Path(config_file_path)
    default_config_path = Path(__file__).parent / '.default.config.ini'
    
    # Load the default config from .default.config.ini
    default_config = configparser.ConfigParser(allow_no_value=True)
    default_config.optionxform = str  # Preserve the letter case of keys
    default_config.read(default_config_path)
    
    # Load the existing config
    current_config = configparser.ConfigParser(allow_no_value=True)
    current_config.optionxform = str  # Preserve the letter case of keys
    current_config.read(config_file_path)
    
    # Collect sections to be removed (present in current but not in default)
    sections_to_remove = [section for section in current_config.sections() if section not in default_config.sections()]
    
    # Prepare the new content by removing sections that are not in the default config
    new_content = []
    in_section_to_remove = False
    
    with config_file_path.open('r') as file:
        for line in file:
            if any(line.strip().lower() == f'[{section.lower()}]' for section in sections_to_remove):
                in_section_to_remove = True
                continue
            if line.startswith('[') and in_section_to_remove:
                in_section_to_remove = False
            if not in_section_to_remove:
                new_content.append(line)
    
    # Write the modified content back to the config file
    with config_file_path.open('w') as file:
        file.writelines(new_content)
    
    # Reload the config to update it with missing sections and options from the default config
    current_config.read_string(''.join(new_content))
    
    for section in default_config.sections():
        if not current_config.has_section(section):
            current_config.add_section(section)
        for key, value in default_config.items(section):
            if not current_config.has_option(section, key):
                current_config.set(section, key, value)
    
    # Write the final updated config back to the file, ensuring new sections and options are added
    with config_file_path.open('w') as file:
        current_config.write(file, space_around_delimiters=False)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_config.py <config_file_path>")
        sys.exit(1)
    
    config_file_path = sys.argv[1]
    update_config(config_file_path)

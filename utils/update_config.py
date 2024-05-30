from pathlib import Path
from configobj import ConfigObj

def update_config():
    config_file_path = str(Path(__file__).parent / 'config.ini')
    default_config_path = str(Path(__file__).parent / '.default.config.ini')

    # Load the existing config and default config
    current_config = ConfigObj(config_file_path, encoding='utf-8', list_values=False)
    default_config = ConfigObj(default_config_path, encoding='utf-8', list_values=False)

    # Remove sections from current config that are not in the default config
    for section in list(current_config.keys()):
        if section not in default_config:
            del current_config[section]

    # Update sections and keys from the default config
    for section, default_options in default_config.items():
        if section not in current_config:
            current_config[section] = default_options
        else:
            # Remove keys not present in the default config
            for key in list(current_config[section].keys()):
                if key not in default_options:
                    del current_config[section][key]
            # Add keys from the default config
            for key, value in default_options.items():
                if key not in current_config[section]:
                    current_config[section][key] = value

    # Write the updated config back to the file
    current_config.write()

if __name__ == "__main__":    
    update_config()

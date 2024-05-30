from pathlib import Path
from configobj import ConfigObj

def update_config():
    config_file_path = str(Path(__file__).parent.parent / 'config.ini')
    default_config_path = str(Path(__file__).parent.parent / '.default.config.ini')

    print(f"Loading current config from: {config_file_path}")
    print(f"Loading default config from: {default_config_path}")

    # Load the existing config and default config
    current_config = ConfigObj(config_file_path, encoding='utf-8', list_values=False)
    default_config = ConfigObj(default_config_path, encoding='utf-8', list_values=False)

    print("Current config sections:", list(current_config.keys()))
    print("Default config sections:", list(default_config.keys()))

    # Remove sections from current config that are not in the default config
    for section in list(current_config.keys()):
        if section not in default_config:
            print(f"Removing section: {section}")
            del current_config[section]

    # Update sections and keys from the default config
    for section, default_options in default_config.items():
        if section not in current_config:
            print(f"Adding missing section: {section}")
            current_config[section] = default_options
        else:
            # Remove keys not present in the default config
            for key in list(current_config[section].keys()):
                if key not in default_options:
                    print(f"Removing key: {key} from section: {section}")
                    del current_config[section][key]
            # Add keys from the default config
            for key, value in default_options.items():
                if key not in current_config[section]:
                    print(f"Adding missing key: {key} to section: {section}")
                    current_config[section][key] = value

    # Write the updated config back to the file
    with open(config_file_path, 'w', encoding='utf-8') as file:
        # Ensure new sections and options are added correctly
        for section in default_config.sections():
            if section not in current_config:
                file.write(f'\n[{section}]\n')
                for key, value in default_config[section].items():
                    if value is None:
                        file.write(f'{key}\n')
                    else:
                        file.write(f'{key}={value}\n')
            else:
                file.write(f'\n[{section}]\n')
                for line in current_config[section].items():
                    file.write(f'{line[0]}={line[1]}\n')
                # Add any missing keys from the default config
                for key, value in default_config[section].items():
                    if key not in current_config[section]:
                        print(f"Adding missing key: {key} to section: {section}")
                        file.write(f'{key}={value}\n')
                    # Write any comments associated with keys
                    elif current_config[section][key] == default_config[section][key]:
                        for comment in default_config.comments[key]:
                            file.write(f'{comment}\n')

    print(f"Updated config written to: {config_file_path}")

if __name__ == "__main__":
    update_config()

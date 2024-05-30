from pathlib import Path
from configobj import ConfigObj

def update_config():
    config_file_path = str(Path(__file__).parent.parent / 'config.ini')
    default_config_path = str(Path(__file__).parent.parent / '.default.config.ini')

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
            current_config.comments[section] = default_config.comments.get(section, [])
        else:
            # Remove keys not present in the default config
            for key in list(current_config[section].keys()):
                if key not in default_options:
                    del current_config[section][key]
            # Add keys from the default config
            for key, value in default_options.items():
                if key not in current_config[section]:
                    current_config[section][key] = value
                    current_config[section].comments[key] = default_config[section].comments.get(key, [])
                if key in default_options.inline_comments:
                    current_config[section].inline_comments[key] = default_options.inline_comments[key]

    # Write the updated config back to the file
    current_config.write()

    # Ensure new lines before new sections
    with open(config_file_path, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    with open(config_file_path, 'w', encoding='utf-8') as file:
        for i, line in enumerate(lines):
            if line.startswith('[') and i != 0 and lines[i-1].strip() != '':
                file.write('\n')
            file.write(line)

if __name__ == "__main__":
    update_config()

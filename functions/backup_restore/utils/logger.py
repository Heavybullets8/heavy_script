import logging
from datetime import datetime, timezone
from pathlib import Path

class Truncator:
    """
    Utility class to truncate strings, dictionaries, and lists to a specified maximum length.
    """
    def __init__(self, max_length=100):
        """
        Initialize the Truncator with a specified maximum length.

        Parameters:
            max_length (int): The maximum length for truncation.
        """
        self.max_length = max_length

    def _truncate(self, value: str) -> str:
        """
        Truncate a string to the maximum length with ellipsis if necessary.

        Parameters:
            value (str): The string to truncate.

        Returns:
            str: The truncated string.
        """
        return (value[:self.max_length] + '...') if len(value) > self.max_length else value

    def truncate_dict(self, d: dict) -> dict:
        """
        Recursively truncate all keys and values in a dictionary.

        Parameters:
            d (dict): The dictionary to truncate.

        Returns:
            dict: The truncated dictionary.
        """
        truncated = {}
        for key, value in d.items():
            truncated_key = self._truncate(str(key))
            if isinstance(value, dict):
                truncated_value = self.truncate_dict(value)
            elif isinstance(value, list):
                truncated_value = [self._truncate(str(v)) if isinstance(v, str) else v for v in value]
            else:
                truncated_value = self._truncate(str(value)) if isinstance(value, str) else value
            truncated[truncated_key] = truncated_value
        return truncated

    def truncate(self, data):
        """
        Truncate the input data if it is a dictionary or a list.

        Parameters:
            data: The data to truncate.

        Returns:
            The truncated data.
        """
        if isinstance(data, dict):
            return self.truncate_dict(data)
        elif isinstance(data, list):
            return [self._truncate(str(item)) for item in data]
        return data

def setup_global_logger(backup_root: str) -> logging.Logger:
    """
    Set up a global logger that logs messages to both a file and the console.

    Parameters:
        backup_root (str): The directory where the log file will be created.

    Returns:
        logging.Logger: The configured logger.
    """
    log_dir = Path(backup_root)
    logger = logging.getLogger('BackupLogger')
    logger.setLevel(logging.DEBUG)

    if not logger.handlers:
        log_filename = log_dir / f".debug_{datetime.now(timezone.utc).strftime('%Y-%m-%d_%H:%M:%S')}.log"
        try:
            fh = logging.FileHandler(log_filename)
            fh.setLevel(logging.DEBUG)
            fh_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(module)s - %(funcName)s - %(message)s')
            fh.setFormatter(fh_formatter)
            logger.addHandler(fh)
        except Exception as e:
            print(f"Failed to set up file handler: {e}")

        ch = logging.StreamHandler()
        ch.setLevel(logging.INFO)
        ch_formatter = logging.Formatter('%(message)s')
        ch.setFormatter(ch_formatter)
        logger.addHandler(ch)

    return logger
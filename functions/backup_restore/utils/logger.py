import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from contextvars import ContextVar

# Context variable to hold the current logger
current_logger: ContextVar[logging.Logger] = ContextVar('current_logger')

def setup_global_logger(operation: str, max_bytes: int = 10*1024*1024, backup_count: int = 5) -> logging.Logger:
    """
    Set up a global logger that logs messages to both a rotating file and the console.

    Parameters:
        operation (str): The operation type (general, import, export, backup, restore).
        max_bytes (int): The maximum size of the log file before rotation (default 10MB).
        backup_count (int): The number of backup files to keep (default 5).

    Returns:
        logging.Logger: The configured logger.
    """
    log_dir = Path(__file__).parent.parent.parent.parent / "logs" / operation
    log_dir.mkdir(parents=True, exist_ok=True)
    log_filename = log_dir / f"{operation}.log"

    logger = logging.getLogger(f'{operation.capitalize()}Logger')
    logger.setLevel(logging.DEBUG)

    # Ensure handlers are not duplicated
    if not logger.handlers:
        try:
            fh = RotatingFileHandler(log_filename, maxBytes=max_bytes, backupCount=backup_count)
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

def get_logger() -> logging.Logger:
    """Retrieve the current logger from the context."""
    return current_logger.get()

def set_logger(logger: logging.Logger):
    """Set the current logger in the context."""
    current_logger.set(logger)

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
        self.logger.debug(f"Truncating dictionary: {d}")
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
        self.logger.debug(f"Truncating data: {data}")
        if isinstance(data, dict):
            return self.truncate_dict(data)
        elif isinstance(data, list):
            return [self._truncate(str(item)) for item in data]
        return data
import subprocess
from utils.logger import get_logger

class CommandResult:
    def __init__(self, output, error, status):
        """
        Initialize the CommandResult class.

        Parameters:
        - output (str): The standard output of the command.
        - error (str): The standard error of the command.
        - status (int): The exit status of the command.
        """
        self.output = output
        self.error = error
        self.status = status

    def is_success(self) -> bool:
        """
        Check if the command executed successfully.

        Returns:
            bool: True if the command executed successfully, False otherwise.
        """
        return self.status == 0

    def get_output(self) -> str:
        """
        Retrieve the standard output of the command.

        Returns:
            str: The standard output of the command.
        """
        return self.output

    def get_error(self) -> str:
        """
        Retrieve the standard error of the command.

        Returns:
            str: The standard error of the command.
        """
        return self.error

def run_command(command: str, suppress_output: bool = False) -> CommandResult:
    """
    Executes a shell command and returns a CommandResult object.

    Parameters:
        command (str): The shell command to execute.
        suppress_output (bool): If True, suppresses the command output in the logs.

    Returns:
        CommandResult: The result of the command execution.
    """
    logger = get_logger()
    logger.debug(f"Executing command: {command}")

    try:
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output, error = process.communicate()
        status = process.returncode

        if not suppress_output:
            logger.debug(f"Command output: {output}")

        if status != 0:
            logger.error(f"Command error: {error}")

        return CommandResult(output.strip(), error.strip(), status)
    except Exception as e:
        logger.error(f"Failed to run command: {command}", exc_info=True)
        return CommandResult(None, str(e), -1)

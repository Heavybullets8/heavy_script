import time, logging
from utils.shell import run_command

def waitForKubernetes(check_interval: int = 15, timeout: int = 1800) -> bool:
    """
    Waits for Kubernetes to report as 'RUNNING'.
    
    Parameters:
        check_interval (int): How often to check the Kubernetes status in seconds.
        timeout (int): How long to wait before timing out in seconds. Set to None to wait indefinitely.
        
    Returns:
        bool: True if Kubernetes is running, False if timed out.
    """
    logger = logging.getLogger('BackupLogger')
    logger.debug("Waiting for Kubernetes to start...")
    
    start_time = time.time()
    command = "cli -m csv -c 'app kubernetes status'"

    while True:
        result = run_command(command, suppress_output=True)
        if result.is_success():
            try:
                status_line = result.get_output().split('\n')[1]  # Get the second line which contains the status
                status = status_line.split(',')[0]  # The first element is the status

                if status == "RUNNING":
                    logger.info("Kubernetes is RUNNING.")
                    return True

                logger.warning(f"Kubernetes status is '{status}'. Waiting...")
            except IndexError:
                logger.error(f"Unexpected output format: {result.get_output()}")
        else:
            logger.error(f"Error executing command: {result.get_error()}")

        # Check if timeout is enabled and if it has been reached
        if timeout is not None and time.time() - start_time > timeout:
            logger.error("Timeout reached while waiting for Kubernetes to start.")
            return False

        time.sleep(check_interval)

def checkKubernetesStatus() -> bool:
    """
    Checks the status of Kubernetes and returns False if status is STOPPED or FAILED, else returns True.
    
    Returns:
        bool: False if Kubernetes status is STOPPED or FAILED, True otherwise.
    """
    logger = logging.getLogger('BackupLogger')
    logger.debug("Checking Kubernetes status...")

    command = "cli -m csv -c 'app kubernetes status'"
    result = run_command(command, suppress_output=True)

    if result.is_success():
        try:
            status_line = result.get_output().split('\n')[1]  # Get the second line which contains the status
            status = status_line.split(',')[0]  # The first element is the status

            if status in ["STOPPED", "FAILED"]:
                logger.error(f"Kubernetes status is '{status}'.")
                return False

            logger.debug(f"Kubernetes status is '{status}'.")
            return True
        except IndexError:
            logger.error(f"Unexpected output format: {result.get_output()}")
    else:
        logger.error(f"Error executing command: {result.get_error()}")

    return False
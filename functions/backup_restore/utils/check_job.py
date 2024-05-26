import time
from utils.logger import get_logger
from utils.singletons import MiddlewareClientManager

def check_job_status(job_id: int) -> bool:
    """
    Check the job status using the job ID.

    Parameters:
        job_id (int): The ID of the job to check.

    Returns:
        bool: True if the job succeeds, False if the job fails or times out.
    """
    middleware = MiddlewareClientManager.fetch()
    logger = get_logger()

    max_retries = 50
    retry_count = 0
    wait_time = 10

    logger.debug(f"Checking status for job ID: {job_id}")
    while retry_count < max_retries:
        try:
            job_details = middleware.call('core.get_jobs', [['id', '=', job_id]])
            if job_details:
                job_state = job_details[0]['state']
                if job_state == 'SUCCESS':
                    logger.debug(f"Job {job_id} completed successfully.")
                    return True
                elif job_state == 'FAILED':
                    error_message = job_details[0].get('error', 'No error message provided.')
                    logger.error(f"Job {job_id} failed: {error_message}")
                    return False
                else:
                    logger.debug(f"Job {job_id} is in state: {job_state}. Retrying in {wait_time} seconds...")
            else:
                logger.error(f"No job details found for job ID: {job_id}. Retrying in {wait_time} seconds...")
        except Exception as e:
            logger.error(f"Failed to fetch job status for job ID: {job_id}: {e}", exc_info=True)

        time.sleep(wait_time)
        retry_count += 1

    logger.error(f"Job status check for job ID: {job_id} timed out after {max_retries * wait_time} seconds.")
    return False

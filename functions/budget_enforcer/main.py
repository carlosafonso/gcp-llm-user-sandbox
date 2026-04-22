import base64
import json
import logging
import os

import functions_framework
from googleapiclient import discovery
from googleapiclient.errors import HttpError

logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))

TARGET_SERVICE = "aiplatform.googleapis.com"


@functions_framework.cloud_event
def disable_vertex_on_budget_alert(cloud_event):
    pubsub_data = base64.b64decode(
        cloud_event.data["message"]["data"]
    ).decode("utf-8")
    payload = json.loads(pubsub_data)
    logger.info("Received budget alert: %s", payload)

    alert_threshold = payload.get("alertThresholdExceeded")
    project_id = payload.get("projectId")

    if alert_threshold is None or alert_threshold < 1.0:
        logger.info("Threshold %.2f < 1.0, skipping.", alert_threshold or 0)
        return

    if not project_id:
        logger.error("No projectId in payload, cannot enforce: %s", payload)
        return

    _disable_service(project_id, TARGET_SERVICE)


def _disable_service(project_id: str, service_name: str) -> None:
    service = discovery.build("serviceusage", "v1", cache_discovery=False)
    name = f"projects/{project_id}/services/{service_name}"
    try:
        operation = service.services().disable(
            name=name,
            body={"disableDependentServices": False},
        ).execute()
        logger.info("Disable operation started: %s", operation.get("name"))
    except HttpError as e:
        if e.resp.status == 404:
            logger.info("Service %s on %s already disabled (404).", service_name, project_id)
        else:
            logger.exception("Failed to disable %s on %s.", service_name, project_id)
            raise

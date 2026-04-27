import json


# -------------------------------------------------------------------
# Lambda Handler
# -------------------------------------------------------------------

def lambda_handler(event, context):
    """
    Receiver Lambda for validated events.

    Handles:
    - API Gateway proxy events (event["body"])
    - Direct Lambda invocation (local testing)
    """
    
    # Case 1: API Gateway HTTP API invocation
    if "body" in event:
        body = json.loads(event["body"])
    else:
        # Case 2: Direct Lambda invocation (local testing)
        body = event

    correlation_id = body.get("metadata", {}).get("correlation_id", "unknown")

    print(json.dumps({
        "correlation_id": correlation_id,
        "message": "validated_event_received",
        "payload": body
    }, indent=2))

    return {
        "statusCode": 200,
        "body": json.dumps({"status": "ok"})
    }

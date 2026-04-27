import json


# -------------------------------------------------------------------
# Lambda Handler
# -------------------------------------------------------------------

def lambda_handler(event, context):
    # API Gateway puts body as string
    body = json.loads(event["body"])

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

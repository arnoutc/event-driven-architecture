import uuid
import json
import os
import urllib.parse
import boto3
from jsonschema import Draft7Validator

# AWS clients
AWS_REGION = os.environ.get("AWS_REGION", "eu-west-2")

s3 = boto3.client("s3", region_name=AWS_REGION)
schemas = boto3.client("schemas", region_name=AWS_REGION)
events = boto3.client("events", region_name=AWS_REGION)

# Environment variables
VALIDATED_BUCKET = os.environ["VALIDATED_BUCKET"]
REJECTED_BUCKET = os.environ["REJECTED_BUCKET"]
SCHEMA_REGISTRY = os.environ["SCHEMA_REGISTRY"]
EVENT_BUS = os.environ.get("EVENT_BUS", "default")

correlation_id = f"corr-{uuid.uuid4()}"

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------


def get_schema(schema_name: str) -> dict:
    """
    Fetch latest JSON schema from EventBridge Schema Registry.
    """
    response = schemas.describe_schema(
        RegistryName=SCHEMA_REGISTRY,
        SchemaName=schema_name
    )
    return json.loads(response["Content"])


def read_json_from_s3(bucket: str, key: str) -> dict:
    """
    Read JSON file from S3 and return as dict.
    """
    response = s3.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


def write_json_to_s3(bucket: str, key: str, data: dict):
    """
    Write JSON file to S3.
    """
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(data, indent=2).encode("utf-8"),
        ContentType="application/json"
    )


def emit_validated_event(payload: dict, metadata: dict):
    """
    Emit a validated event to EventBridge.
    This event is consumed by downstream rules (e.g. API Destination).
    """
    response = events.put_events(
        Entries=[
            {
                "Source": "com.example.validation",
                "DetailType": "JsonValidated",
                "Detail": json.dumps({
                    "data": payload,
                    "metadata": metadata
                }),
                "EventBusName": EVENT_BUS
            }
        ]
    )

    if response["FailedEntryCount"] > 0:
        raise RuntimeError("Failed to emit validated event")


def log(msg: str, **fields):
    record = {
        "correlation_id": correlation_id,
        **fields,
        "message": msg
    }
    print(json.dumps(record))


# -------------------------------------------------------------------
# Lambda Handler
# -------------------------------------------------------------------

def lambda_handler(event, context):
    """
    Validates a JSON object uploaded to S3 against a JSON Schema.

    - INVALID: write error report to REJECTED_BUCKET
    - VALID:   write JSON to VALIDATED_BUCKET and emit EventBridge event
    """

    LOCAL_MODE = os.environ.get("LOCAL_MODE") == "true"

    if LOCAL_MODE:
        print("LOCAL_MODE: Skipping S3 + Schemas")
        print("Event received:", json.dumps(event, indent=2))
        return {"status": "LOCAL_OK"}

    # Extract S3 details from EventBridge event
    detail = event["detail"]
    source_bucket = detail["bucket"]["name"]

    raw_key = detail["object"]["key"]
    object_key = urllib.parse.unquote_plus(raw_key)

    print(f"Validating s3://{source_bucket}/{object_key}")

    try:
        correlation_id = f"corr-{uuid.uuid4()}"

        log("validation_started",
            bucket=source_bucket,
            key=object_key)

        payload = read_json_from_s3(source_bucket, object_key)

        # ------------------------------------------------------------
        # Schema resolution strategy
        # ------------------------------------------------------------
        if object_key.startswith("orders/v1/"):
            schema_name = "orders-v1"
        else:
            raise RuntimeError("No schema mapping found for object key")

        schema = get_schema(schema_name)

        # ------------------------------------------------------------
        # Validate JSON
        # ------------------------------------------------------------
        validator = Draft7Validator(schema)
        errors = sorted(validator.iter_errors(payload), key=lambda e: e.path)

        # ------------------------------------------------------------
        # INVALID JSON → reject
        # ------------------------------------------------------------
        if errors:
            error_report = {
                "correlation_id": correlation_id,
                "source": f"s3://{source_bucket}/{object_key}",
                "schema": schema_name,
                "errors": [
                    {
                        "path": list(error.path),
                        "message": error.message
                    }
                    for error in errors
                ]
            }

            write_json_to_s3(
                REJECTED_BUCKET,
                f"{object_key}.errors.json",
                error_report
            )

            return {
                "status": "INVALID",
                "errors": len(error_report["errors"])
            }

        # ------------------------------------------------------------
        # VALID JSON → persist + forward
        # ------------------------------------------------------------
        write_json_to_s3(
            VALIDATED_BUCKET,
            object_key,
            payload
        )

        emit_validated_event(
            payload=payload,
            metadata={
                "correlation_id": correlation_id,
                "bucket": source_bucket,
                "key": object_key,
                "schema": schema_name
            }
        )

        return {
            "status": "VALID",
            "bucket": source_bucket,
            "key": object_key,
            "forwarded": True
        }

    except Exception as e:
        print("Unhandled error:", str(e))
        raise

import json
import os
import urllib.parse
import boto3
from jsonschema import Draft7Validator

s3 = boto3.client("s3")
schemas = boto3.client("schemas")

VALIDATED_BUCKET = os.environ["VALIDATED_BUCKET"]
REJECTED_BUCKET = os.environ["REJECTED_BUCKET"]
SCHEMA_REGISTRY = os.environ["SCHEMA_REGISTRY"]

# ---- Helpers --------------------------------------------------


def get_schema(schema_name: str ) -> dict:
    """
    Fetch JSON schema from EventBridge Schema Registry

    :param schema_name: name of schema to fetch
    :param schema_version: version of schema to fetch (default: latest)
    :return: JSON schema as dict
    """
    response = schemas.describe_schema(
        RegistryName=SCHEMA_REGISTRY,
        SchemaName=schema_name
    )

    return json.loads(response["Content"])


def read_json_from_s3(bucket: str, key: str) -> dict:
    """
    Read JSON file from S3 and return as dict

    :param bucket: S3 bucket name
    :param key: S3 object key
    :return: JSON content as dict
    """
    response = s3.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


def write_json_to_s3(bucket: str, key: str, data: dict):
    """
    Write JSON file to S3

    :param bucket: S3 bucket name
    :param key: S3 object key
    """
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(data, indent=2).encode("utf-8"),
        ContentType='application/json'
    )


# ---- Core Handler ---------------------------------------------

def lambda_handler(event, context):
    """
    Validates a JSON object uploaded to S3 against a JSON Schema.
    """

    LOCAL_MODE = os.environ.get("LOCAL_MODE") == "true"

    if LOCAL_MODE:
        print("LOCAL_MODE: Skipping S3 + Schemas")
        print("Event received:", json.dumps(event, indent=2))
        return {
            "status": "LOCAL_OK"
        }

    # Extract S3 details from EventBridge event
    detail = event["detail"]
    source_bucket = detail["bucket"]["name"]

    raw_key = detail["object"]["key"]
    object_key = urllib.parse.unquote_plus(raw_key)

    print(f"Validating s3://{source_bucket}/{object_key}")

    try:
        payload = read_json_from_s3(source_bucket, object_key)

        # ---- Schema Resolution Strategy ----
        # Example: schema by prefix
        # /orders/v1/*.json -> orders-v1 schema
        if object_key.startswith("orders/v1/"):
            schema_name = "orders-v1"
        else:
            raise Exception("No schema mapping found")

        schema = get_schema(schema_name)

        validator = Draft7Validator(schema)
        errors = sorted(validator.iter_errors(payload), key=lambda e: e.path)

        if errors:
            error_report = {
                "source": f"s3://{source_bucket}/{object_key}",
                "errors": [
                    {
                        "path": list(error.path),
                        "message": error.message
                    }
                    for error in errors
                ]
            }
            write_json_to_s3(REJECTED_BUCKET, 
                             f"{object_key}.errors.json", error_report)
            return {
                "status": "INVALID",
                "errors": len(error_report["errors"])
            }

        # ✅ VALID
        destination_key = object_key
        write_json_to_s3(VALIDATED_BUCKET, destination_key, payload)

        return {
            "status": "VALID",
            "bucket": source_bucket,
            "key": object_key
        }

    except Exception as e:
        print("Unhandled error", str(e))
        raise e

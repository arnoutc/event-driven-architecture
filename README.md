# Event‑Driven JSON Ingestion & Validation on AWS

This repository contains a **serverless, event‑driven architecture** for validating JSON files uploaded to Amazon S3 against versioned JSON Schemas, using **Amazon EventBridge**, **AWS Lambda**, and the **EventBridge Schema Registry**.

The design emphasizes **decoupling, validation at the boundary, and schema governance**, while remaining simple, observable, and cost‑efficient.

---

## 🧠 Architecture Overview

![Event-driven architecture diagram](architecture.png)

### High‑level flow

```
S3 (JSON uploaded)
→ EventBridge (Object Created event)
→ EventBridge Rule (filter .json)
→ Lambda (JSON Schema validation)
→ S3 (validated / rejected)
```

### Key principles

- Event‑driven, not request‑driven
- JSON schema validation at ingestion boundaries
- Strong separation of concerns
- No polling, no API Gateway
- Native AWS integrations only

---

## 🧩 Components

### Amazon S3
- Entry point for JSON ingestion
- Publishes object‑level events directly to EventBridge
- Uses suffix convention (`.json`)

### Amazon EventBridge
- Receives S3 `Object Created` events
- Filters relevant objects using rules
- Routes events to validation Lambda
- Enables decoupling, retries, replay, and fan‑out

### EventBridge Schema Registry
- Stores **JSON Schemas for file contents**
- Manages schema versioning and evolution
- Schema versions are numeric and monotonic
- Lambda always retrieves the latest schema version

> Note: The Schema Registry is used for **data schemas**, not S3 event schemas.

### AWS Lambda (Validator)
- Triggered by EventBridge
- Responsibilities:
  1. Load JSON file from S3
  2. Select schema based on object key
  3. Fetch schema from EventBridge Schema Registry
  4. Validate JSON using `jsonschema`
  5. Route result:
     - ✅ Valid → validated bucket
     - ❌ Invalid → rejected bucket with error report

- Runs on **ARM64**
- Uses a Lambda Layer for third‑party dependencies

---

## 📁 Repository Structure

```terminal
├── Makefile
├── lambda/
│   ├── schema              # sample JSON to ingest in S3 injection bucket and sample JSON Schema
│   ├── handler.py          # Lambda handler (function code)
│   └── test_event.json     # Local EventBridge test event
├── layer/
│   ├── requirements.txt    # Runtime dependencies
│   └── python/             # Built Lambda layer contents
├── lambda.zip              # Function artifact (generated)
├── lambda-layer.zip        # Layer artifact (generated)
└── .terraform/
└── *.tf                    # Infrastructure as Code
```

## 🧪 Local Development & Testing

Local testing uses the **official AWS Lambda Docker image**, providing strong parity with the AWS runtime.

### Build artifacts

```bash
make build
```

This:

- Builds dependencies inside Amazon Linux
- Produces:
  - lambda.zip
  - lambda-layer.zip

### Run Lambda locally

Run in a terminal:

```bash
make local
```

### Invoke locally

Run in a second terminal:

```bash
curl -X POST \
  http://localhost:9000/2015-03-31/functions/function/invocations \
  -d @lambda/test_event.json
```

### Expected response

In first terminal:

```bash
Event received: {
  "detail": {
    "bucket": {
      "name": "json-ingestion-43aa86fb"
    },
    "object": {
      "key": "orders/v1/order.json"
    }
  }
}
```

In second terminal:
```bash
{ "status": "LOCAL_OK" }
```

### Deployment

Infrastructure is provisioned using Terraform.

Key configuration points:

- S3 bucket has eventbridge = true
- EventBridge rule filters .json objects
- Lambda configuration:
  - runtime: python3.12
  - architecture: arm64
  - handler: handler.lambda_handler
  - dependency layer attached

#### Deploy with:

```bash
terraform plan -out dev.plan
terraform apply "dev.plan"
```

### JSON Schema Example

Example schema stored in EventBridge Schema Registry (orders-v1):

```bash
 {
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Order",
  "type": "object",
  "additionalProperties": false,
  "required": ["orderId", "amount"],
  "properties": {
    "orderId": {
      "type": "string",
      "minLength": 1
    },
    "amount": {
      "type": "number",
      "minimum": 0
    }
  }
}
```

Schemas are strict by default, centrally versioned, and retrieved dynamically by the Lambda.

### Key Design Decisions

#### Why EventBridge instead of SNS/SQS/Lambda triggers?

- Rich filtering
- Fan‑out without refactoring
- Built‑in retries and replay
- Cleaner decoupling

#### Why Schema Registry?

- Central governance of contracts
- Version history and evolution
- No redeploy needed for schema changes

#### Why Lambda Layer?

- Native dependencies (rpds)
- Smaller function ZIP
- Faster cold starts
- Clean CI/CD separation

#### Why ARM64?

- Matches Apple Silicon local builds
- Lower cost
- Better performance
- Avoids native extension mismatch

### ⚠️ Common Pitfalls (Already Addressed)

- S3 → EventBridge propagation delays
- Terraform provider syntax for EventBridge
- Lambda ZIP structure (handler at root)
- Native dependency architecture mismatch
- SchemaVersion misuse (latest is invalid)
- Local vs AWS credential behavior

### ✅ Production Readiness Checklist

- Event‑driven ingestion
- Boundary validation
- Schema governance
- Decoupled components
- Reproducible builds
- Local / AWS parity
- Native dependency correctness
PYTHON_VERSION=3.12
LAMBDA_IMAGE=public.ecr.aws/lambda/python:$(PYTHON_VERSION)

LAYER_DIR=layer
LAYER_ZIP=lambda-layer.zip

VALIDATOR_ZIP=lambda.zip
RECEIVER_ZIP=receiver.zip

.PHONY: clean layer package-validator package-receiver build local-validator local-receiver

### Clean build artifacts
clean:
	rm -rf $(LAYER_DIR)/python
	rm -f $(LAYER_ZIP) $(VALIDATOR_ZIP) $(RECEIVER_ZIP)

### Build Lambda Layer dependencies (Amazon Linux)
layer:
	mkdir -p $(LAYER_DIR)/python
	docker run --rm \
		-v "$$(pwd)/$(LAYER_DIR)":/opt \
		--entrypoint /bin/bash \
		$(LAMBDA_IMAGE) \
		-c "pip install -r /opt/requirements.txt -t /opt/python"
	cd $(LAYER_DIR) && zip -r ../$(LAYER_ZIP) python

### Package validator Lambda (handler.py)
package-validator:
	cd lambda && zip -r ../$(VALIDATOR_ZIP) handler.py

### Package receiver Lambda (receiver.py)
package-receiver:
	cd receiver && zip -r ../$(RECEIVER_ZIP) receiver.py

### Full build
build: clean layer package-validator package-receiver

# -------------------------------------------------------------------
# Local testing
# -------------------------------------------------------------------

### Local test: validator Lambda
local-validator:
	docker run --rm \
		-p 9000:8080 \
		-e AWS_REGION=eu-west-2 \
		-e AWS_DEFAULT_REGION=eu-west-2 \
		-e VALIDATED_BUCKET=json-validated-local \
		-e REJECTED_BUCKET=json-rejected-local \
		-e SCHEMA_REGISTRY=json-file-ingestion \
		-e EVENT_BUS=default \
		-e LOCAL_MODE=true \
		-v "$$(pwd)/lambda":/var/task \
		-v "$$(pwd)/$(LAYER_DIR)/python":/opt/python \
		$(LAMBDA_IMAGE) handler.lambda_handler

### Local test: receiver Lambda
local-receiver:
	docker run --rm \
		-p 9001:8080 \
 		-e AWS_REGION=eu-west-2 \
		-e AWS_DEFAULT_REGION=eu-west-2 \
		-v "$$(pwd)/receiver":/var/task \
		$(LAMBDA_IMAGE) receiver.lambda_handler
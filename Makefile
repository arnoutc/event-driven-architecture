PYTHON_VERSION=3.12
LAMBDA_IMAGE=public.ecr.aws/lambda/python:$(PYTHON_VERSION)

LAYER_DIR=layer
LAYER_ZIP=lambda-layer.zip
FUNCTION_ZIP=lambda.zip

.PHONY: clean layer package test local

### Clean
clean:
	rm -rf $(LAYER_DIR)/python
	rm -f $(LAYER_ZIP) $(FUNCTION_ZIP)

### Build Lambda Layer dependencies (Amazon Linux)
layer:
	mkdir -p $(LAYER_DIR)/python
	docker run --rm \
		-v "$$(pwd)/$(LAYER_DIR)":/opt \
		--entrypoint /bin/bash \
		$(LAMBDA_IMAGE) \
		-c "pip install -r /opt/requirements.txt -t /opt/python"
	cd $(LAYER_DIR) && zip -r ../$(LAYER_ZIP) python

### Package Lambda function code only
package:
	cd lambda && zip -r ../$(FUNCTION_ZIP) handler.py

### Full build
build: clean layer package

### Local Lambda test (Docker)
local:
	docker run --rm \
		-p 9000:8080 \
		-e AWS_REGION=eu-west-2 \
		-e AWS_DEFAULT_REGION=eu-west-2 \
		-e VALIDATED_BUCKET=json-validated-local \
		-e REJECTED_BUCKET=json-rejected-local \
		-e SCHEMA_REGISTRY=json-file-ingestion \
		-e LOCAL_MODE=true \
		-v "$$(pwd)/lambda":/var/task \
		-v "$$(pwd)/$(LAYER_DIR)/python":/opt/python \
		$(LAMBDA_IMAGE) handler.lambda_handler
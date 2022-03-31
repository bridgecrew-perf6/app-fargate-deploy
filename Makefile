cnf ?= .env.aws
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

# Get the latest tag
TAG=$(shell git describe --tags --abbrev=0)
GIT_COMMIT=$(shell git log -1 --format=%h)
AWS_ACCOUNT=111111111111111
TERRAFORM_VERSION=0.12.24
AWS_DEFAULT_REGION="us-east-1"

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

build: ## Build Artifact image
	docker build -t app:$(GIT_COMMIT) .

ecr-tag: ecr-login build ## Create a tag from the current docker image.
	docker tag app:$(GIT_COMMIT) $(AWS_ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/app:$(GIT_COMMIT)
	docker tag app:$(GIT_COMMIT) $(AWS_ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/app:latest

ecr-push: ecr-tag ## Push images to ECR.
	docker push $(AWS_ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/app:$(GIT_COMMIT)
	docker push $(AWS_ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/app:latest

ecr-login: ## Get credentials to login to ecr. This credentials expire in 24h.
	docker run --rm -v $$PWD:/app -w /app -e "AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID" -e "AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY" --entrypoint "" mesosphere/aws-cli sh -c "aws ecr get-login --region us-east-1 --no-include-email" > docker-login.sh
	cat docker-login.sh
	sh docker-login.sh
	rm docker-login.sh

terraform-init: ## Run terraform init to download all necessary plugins
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) init -upgrade=true

terraform-plan: ## Exec a terraform plan and puts it on a file called tfplan
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) plan -out=tfplan

terraform-apply: ## Uses tfplan to apply the changes on AWS.
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) apply -auto-approve

terraform-destroy: ## Destroy all resources created by the terraform file in this repo.
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) destroy -auto-approve

terraform-set-workspace-dev: ## Set workspace dev
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) workspace select dev

terraform-set-workspace-staging: ## Set workspace staging
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) workspace select staging

terraform-set-workspace-prod: ## Set workspace staging
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) workspace select prod

terraform-new-workspace-staging: ## Create workspace staging
	  docker run --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) hashicorp/terraform:$(TERRAFORM_VERSION) workspace new staging

terraform-sh: ## Set workspace staging
	  docker run -it --rm -v $$PWD:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) --entrypoint "" hashicorp/terraform:$(TERRAFORM_VERSION) sh

terraform-ls: ## Set workspace staging
	  docker run -it --rm -v $$CIRCLE_WORKING_DIRECTORY:/app -v $$HOME/.ssh/:/root/.ssh/ -w /app/ -e AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) --entrypoint "" hashicorp/terraform:$(TERRAFORM_VERSION) ls -la /root/.ssh/

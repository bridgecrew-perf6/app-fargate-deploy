terraform {
  backend "s3" {
    bucket = "descomplicando-terraform-gomex-tfstates"
    key    = "app/terraform.tfstate"
    region = "us-east-1"
  }
}

module "app-deploy" {
  source                 = "git@github.com:gomex/terraform-module-fargate-deploy.git?ref=v0.2"
  containers_definitions = data.template_file.containers_definitions_json.rendered
  environment            = "development"
  subdomain_name         = "turma2"
  app_name               = "app"
  hosted_zone_id         = "Z05386453E84ZOATUGO7T"
  app_port               = "80"
  cloudwatch_group_name  = "development-app"
}

################   DATA   ################ 

data "template_file" "containers_definitions_json" {
  template = file("./containers_definitions.json")

  vars = {
    APP_VERSION = var.APP_VERSION
    APP_IMAGE   = var.APP_IMAGE
    ENVIRONMENT = "development"
    AWS_REGION  = var.aws_region
  }
}

################   VARIABLES   ################ 
variable "APP_VERSION" {
}

variable "APP_IMAGE" {
  default = "app"
}

variable "aws_region" {
  default = "us-east-1"
}


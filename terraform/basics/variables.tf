variable "aws_region" {
    description = "AWS Deployment region"
    type = string
    default = "ap-south-2"
  
}

variable "instance_type" {
    description = "Ec2 Instance type"
    type = string
    default = "t3.micro"

    validation {
        condition = contains(
            ["t3.micro", "t3.small"],
            var.instance_type
        )
        error_message = "unsupported instace type"
    }  
}

locals {
  project_name = "terraform-lab"
  environment = "dev"

  common_tags = {
    project = local.project_name
    Environment = local.environment
    ManagedBy = "Terraform"
  }
}
provider "aws" {
    region = "ap-south-2"
}


data "aws_ami" "amazon_linux" {
    most_recent = true

    owners = ["amazon"]

    filter {
      name = "name"
      values = ["al2023-ami-*-x86_64"]
    }

    filter {
        name = "state"
        values = ["available"]
    }
}

resource "aws_instance" "test-instance" {
    ami = var.aws_region
    instance_type = var.instance_type
    associate_public_ip_address = true

    tags = {
      Name = "test-instance-1"
    }
  
}
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
    ami = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type
    associate_public_ip_address = true

    tags = merge(
    local.common_tags,
    {
      Name = "test-instance"
    }
  )
  
}


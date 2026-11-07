output "instance_id" {
    description = "Ec2 Instance ID"
    value = aws_instance.test-instance.id
}

output "public_ip" {
    description = "Ec2 Public IP"
    value = aws_instance.test-instance.public_ip
  
}
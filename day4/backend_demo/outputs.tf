output "vpc_id" {
  value = aws_vpc.main.id
}

output "web_instance_ips" {
  value = aws_instance.web[*].public_ip
}

output "named_instance_ips" {
  value = { for k, v in aws_instance.named : k => v.public_ip }
}

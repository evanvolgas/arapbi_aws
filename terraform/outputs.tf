output "public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "The public IP of the Instance"
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.arapbi.endpoint
}
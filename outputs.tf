output "file_system_dns_name" {
  value = aws_efs_file_system.this.dns_name
}
output "file_system_arn" {
  value = aws_efs_file_system.this.arn
}

output "ec2_security_group_id" {
  value = aws_security_group.mount_target_client.id
}

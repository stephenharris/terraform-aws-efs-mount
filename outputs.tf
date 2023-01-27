output "file_system_dns_name" {
  value = aws_efs_file_system.this.dns_name
}

output "file_system_arn" {
  value = aws_efs_file_system.this.arn
}

output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "ec2_security_group_id" {
  value = aws_security_group.mount_target_client.id
}

output "mount_target_ids" {

  value =  [for mount_target in  aws_efs_mount_target.this: mount_target.id ]
}

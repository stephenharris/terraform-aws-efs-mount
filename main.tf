resource "random_id" "creation_token" {
  byte_length = 8
  prefix      = "${var.name}-"
}

resource "aws_efs_file_system" "this" {
  creation_token = random_id.creation_token.hex

  encrypted  = var.encrypted
  kms_key_id = var.kms_key_id
  
  throughput_mode = var.throughput_mode
  
  lifecycle_policy {
    transition_to_ia = var.transition_to_ia == "" ? null : var.transition_to_ia
    transition_to_primary_storage_class = var.transition_to_ia == "" ? null : "AFTER_1_ACCESS"
  }
  
  tags = merge({Name = "${var.name}", CreationToken = "${random_id.creation_token.hex}", terraform = true}, var.tags)
}

resource "aws_efs_mount_target" "this" {
  count = length(var.subnets)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = element(var.subnets, count.index)
  security_groups = [aws_security_group.mount_target.id]
}

resource "aws_security_group" "mount_target_client" {
  name        = "${var.name}-mount-target-client"
  description = "Allow traffic out to NFS for ${var.name}-mnt."
  vpc_id      = var.vpc_id

  depends_on = [aws_efs_mount_target.this]

  tags = merge(
    {
      Name = "${var.name}-mount-target-client",
      terraform = true
    },
    var.tags,
  )
}

resource "aws_security_group_rule" "nfs_egress" {
  description              = "Allow NFS traffic out from EC2 to mount target"
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mount_target_client.id
  source_security_group_id = aws_security_group.mount_target.id
}

resource "aws_security_group" "mount_target" {
  name        = "${var.name}-mount-target"
  description = "Allow traffic from instances using ${var.name}-ec2."
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name = "${var.name}-mount-target",
      terraform = true
    },
    var.tags
  )
}

resource "aws_security_group_rule" "nfs_ingress" {
  description              = "Allow NFS traffic into mount target from EC2"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mount_target.id
  source_security_group_id = var.cidr_blocks == [] ? aws_security_group.mount_target_client.id : null
  cidr_blocks              = var.cidr_blocks == [] ? null: var.cidr_blocks
}

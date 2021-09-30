resource "random_id" "creation_token" {
  byte_length = 8
  prefix      = "${var.name}-"
}

resource "aws_efs_file_system" "this" {
  creation_token = random_id.creation_token.hex

  encrypted  = var.encrypted
  kms_key_id = var.kms_key_id

  tags = merge(
    tomap({ Name = var.name }),
    tomap({ CreationToken = random_id.creation_token.hex }),
    tomap({ terraform = "true" }),
    var.tags,
  )
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
    tomap({ Name = "${var.name}-mount-target-client" }),
    tomap({ terraform = "true" }),
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
    tomap({ Name = "${var.name}-mount-target" }),
    tomap({ terraform = "true" }),
    var.tags,
  )
}

resource "aws_security_group_rule" "nfs_ingress" {
  description              = "Allow NFS traffic into mount target from EC2"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mount_target.id
  source_security_group_id = aws_security_group.mount_target_client.id
}

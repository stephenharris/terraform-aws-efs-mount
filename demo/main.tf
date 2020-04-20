provider "aws" {
  region  = "eu-west-1"
}

module "networking" {
  source = "terraform-aws-modules/vpc/aws"

  name               = "${var.env_name}"
  cidr               = "10.0.0.0/16"
  azs                = ["eu-west-1a"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_dns_support = true
}

module "efs_mount" {
  source = "../"
  name    = "my-efs-mount"
  subnets = module.networking.public_subnets
  vpc_id  = module.networking.vpc_id
}

# Demo, create two EC2 instances with SSH access and a key-pair to access them 
resource "tls_private_key" "tmp" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "user-ssh-key" {
  key_name   = "my-efs-mount-key"
  public_key = tls_private_key.tmp.public_key_openssh
}

resource "aws_instance" "example-instance-with-efs" {
  count = 2

  ami                    = "ami-00890f614e48ce866"
  subnet_id              = module.networking.public_subnets[count.index]
  vpc_security_group_ids = [
    aws_security_group.ec2.id,
    module.efs_mount.ec2_security_group_id, # EFS access
  ]
  instance_type          = "t2.micro"

  key_name = aws_key_pair.user-ssh-key.key_name


  provisioner "remote-exec" {
    inline = [
      # mount EFS volume
      # https://docs.aws.amazon.com/efs/latest/ug/gs-step-three-connect-to-ec2-instance.html
      # create a directory to mount our efs volume to
      "sudo mkdir -p /mnt/efs",
      # mount the efs volume
      "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${module.efs_mount.file_system_dns_name}:/ /mnt/efs",
      # create fstab entry to ensure automount on reboots
      # https://docs.aws.amazon.com/efs/latest/ug/mount-fs-auto-mount-onreboot.html#mount-fs-auto-mount-on-creation
      "sudo su -c \"echo '${module.efs_mount.file_system_dns_name}:/ /mnt/efs nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\"" #create fstab entry to ensure automount on reboots
    ]
  }

  connection {
    host        = self.public_ip
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.tmp.private_key_pem
  }

}

resource "aws_security_group" "ec2" {
  name        = "ssh-access-to-test"
  description = "Allow ssh inbound traffic"
  vpc_id      = "vpc-1234abcd"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Optional - backups of EFS
resource "aws_backup_selection" "backup_efs" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "my-efs"
  plan_id      = aws_backup_plan.efs_backup_schedule.id

  resources = [
    module.efs_mount.file_system_arn
  ]
}

resource "aws_backup_plan" "efs_backup_schedule" {
  name = "my-efs-mount-backup-schedule"

  rule {
    rule_name         = "my-efs-mount-backup-schedule"
    target_vault_name = aws_backup_vault.efs.name
    schedule          = "cron(23 1 * * ? *)"
    completion_window   = 360 # 6 hours
    lifecycle {
      cold_storage_after = 7
      delete_after       = 97
    }
    recovery_point_tags = {
      Environment = "my-efs-mount"
    }
  }

  tags = {
    Name = "my-efs-mount"
  }
}


resource "aws_backup_vault" "efs" {
  name        = "example_backup_vault"
}


resource "aws_iam_role" "backup_role" {
  name               = "my-efs-mount-backup-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_aws_backup_service_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

output "private_key" {
  value = tls_private_key.tmp.private_key_pem
}

output "ec2_ip" {
  value = aws_instance.example-instance-with-efs[0].public_ip
}

output "ec2_ip_2" {
  value = aws_instance.example-instance-with-efs[1].public_ip
}

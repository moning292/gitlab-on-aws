data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gitlab-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "gitlab-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gitlab-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gitlab-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "gitlab" {
  name        = "gitlab-sg"
  description = "Security group for GitLab"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitlab-sg"
  }
}

resource "aws_efs_file_system" "gitlab" {
  encrypted = true

  tags = {
    Name = "gitlab-efs"
  }
}

resource "aws_efs_mount_target" "gitlab" {
  file_system_id  = aws_efs_file_system.gitlab.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "gitlab-efs-sg"
  description = "Security group for GitLab EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.gitlab.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitlab-efs-sg"
  }
}

resource "aws_s3_bucket" "gitlab_backups" {
  bucket_prefix = "gitlab-backups-"

  tags = {
    Name = "gitlab-backups"
  }
}

resource "aws_s3_bucket_versioning" "gitlab_backups" {
  bucket = aws_s3_bucket.gitlab_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "gitlab" {
  name = "gitlab-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "gitlab_s3" {
  name = "gitlab-s3-policy"
  role = aws_iam_role.gitlab.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.gitlab_backups.arn,
        "${aws_s3_bucket.gitlab_backups.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "gitlab" {
  name = "gitlab-instance-profile"
  role = aws_iam_role.gitlab.name
}

resource "aws_instance" "gitlab" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.gitlab.id]
  iam_instance_profile   = aws_iam_instance_profile.gitlab.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/install_gitlab.sh", {
    efs_id        = aws_efs_file_system.gitlab.id
    s3_bucket     = aws_s3_bucket.gitlab_backups.id
    aws_region    = var.aws_region
  })

  depends_on = [aws_efs_mount_target.gitlab]

  tags = {
    Name = "gitlab-ce"
  }
}

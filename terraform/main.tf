terraform {
  backend "s3" {
    bucket = "arapbi-terraform"
    key    = "prod/services/default.tfstate"
    region = "us-west-2"
  }
}

resource "aws_s3_bucket" "arapbi" {
  bucket = "arapbi"

  tags = {
    Name = "ARAPBI"
  }
  lifecycle {
    prevent_destroy = true
  }

}

resource "aws_s3_bucket_lifecycle_configuration" "arapbi" {
  bucket = aws_s3_bucket.arapbi.id

  rule {
    id     = "Arapbi Athena Results Lifecycle"
    status = "Enabled"

    filter {
      prefix = "athena_results/"
    }

    expiration {
      days = 3
    }
  }
}

resource "aws_vpc" "arapbi" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ARAPBI"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.arapbi.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.arapbi.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.arapbi.id

  tags = {
    Name = "Arapbi VPC IG"
  }
}

resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.arapbi.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "2nd Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt.id
}

resource "aws_security_group" "bastion" {
  name   = "Bastion host"
  vpc_id = aws_vpc.arapbi.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0395649fbe870727e"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.arapbi.key_name

  tags = {
    Name = "bastion"
    Tag  = "Managed by Terraform"
  }
}

resource "tls_private_key" "arapbi" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "arapbi" {
  key_name   = "arapbi-ssh-key"
  public_key = tls_private_key.arapbi.public_key_openssh
}

resource "local_sensitive_file" "arapbi" {
  content  = tls_private_key.arapbi.private_key_openssh
  filename = "${path.module}/sshkey-${aws_key_pair.arapbi.key_name}"
}

resource "aws_security_group" "database" {
  name   = "DB Host"
  vpc_id = aws_vpc.arapbi.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "arapbi" {
  name       = "arapbi"
  subnet_ids = aws_subnet.private_subnets.*.id
  tags = {
    Name = "ARAPBI"
  }
}

resource "aws_db_instance" "arapbi" {
  identifier_prefix      = "arapbi"
  engine                 = "postgres"
  allocated_storage      = 10
  instance_class         = "db.t4g.micro"
  db_name                = "arapbi"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.arapbi.id
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
  skip_final_snapshot    = true
  storage_encrypted      = true
  publicly_accessible    = false

  tags = {
    Name = "ARAPBI"
    Tag  = "Managed by Terraform"
  }
}

resource "aws_security_group" "elasticsearch" {
  name   = "elasticsearch"
  vpc_id = aws_vpc.arapbi.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_user" "arapbi" {
  name = "arapbi"
}

resource "aws_iam_user_ssh_key" "arapbi" {
  username   = aws_iam_user.arapbi.name
  encoding   = "SSH"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzoqADrTAICNuay1UFVH4oQuCDnz46G/wK3OKqeex6e9uLVA1SeoiGnPnsl4bRSRfXGTgpAtXIjlww/ICYQUtTiZZnGV0e8Eq9QUlI72rd3zH8wCMxnUkDi27Dg2opsMeFQZKIm/EwnllhAxr7vJn9F9NWfJoBkisSb7cqKGmt6q1T+qQ1IX7JHdnK8JD0Ao/z3PARGOPZXQ5POHQZGgbEDxhx4m5gfhYomfZBhmFsVdKxKCIV7/5/cMd85tlZxI4eo4BUwl+6DRuVf23qccICN8zk5Dq4h7HuU7n/LjI0Dm74RuqsXhbLdEzZv3KSpiWUjCBA8Zu5mil35E0o/UzvOq/VMNYCV94OpStXsLyGL6SsjvcvFllubtyHKXYlh34Xq874YA353B4hdUPXQ3clYU4UJ2FCj93OPZmBr9p6+vORkwiSmdPHS2E9cYQ7kj+DpHlhlHZvRCNoto1mu5lOANweYsP9GIfTXsuQ7Pnue1UV6iAgdgNlT5CVpW1/gIBVqCYKD5lZ68MpER4THEi6j47idBFH8ikt+cY8aSJVVWbkpfqxD0jwq6Y5USHQ0tG1N5faoqzvpZgeda9pP5xxSvGXydDIez7CYdjJbcqJ5m/4vdSPnnshaCZ8YGnbAvGRtF3YW+MfIRdIyqYt90cTj/khUa1QPhCX8RCEwCWISQ== evan.volgas@gmail.com"
}

resource "aws_iam_group" "arapbi_developers" {
  name = "arapbi_developers"
}

resource "aws_iam_group_membership" "arapbi_developers" {
  name = "arapbi_developers_members"
  group = aws_iam_group.arapbi_developers.name

  users = [
    aws_iam_user.arapbi.name,
  ]
}


resource "aws_iam_group_policy" "arapbi_developers" {
  name  = "arapbi_developers_policy"
  group = aws_iam_group.arapbi_developers.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "athena:*",
          "ec2:*",
          "ec2-instance-connect:*",
          "es:*",
          "glue:*",
          "iam:*",
          "rds:*",
          "s3:*",
          "secretsmanager:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

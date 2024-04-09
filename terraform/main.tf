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
}

resource "aws_s3_bucket_lifecycle_configuration" "arapbi" {
  bucket = aws_s3_bucket.arapbi.id

  rule {
    id     = "Lifecycle"
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
    Name = "Project VPC IG"
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
  name   = var.security_group_name
  vpc_id = aws_vpc.arapbi.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

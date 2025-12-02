# S3 bucket
resource "aws_s3_bucket" "dev_bucket" {
  bucket = "my-dev-terraform-bucket1-${var.environment}"

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-s3-bucket"
  }
}

# EC2 instance
resource "aws_instance" "web" {
  ami                    = "ami-0fa3fe0fa7920f68e" # Amazon Linux 2 AMI
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.PublicSubnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  monitoring             = var.monitoring_enabled

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-ec2-instance"
  }
}

# VPC
resource "aws_vpc" "myvpc1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "PublicSubnet" {
  vpc_id            = aws_vpc.myvpc1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "PrivateSubnet" {
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc1.id
  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.PublicSubnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security group for EC2 instance
resource "aws_security_group" "web_sg" {
  name        = "${var.environment}-web-sg"
  description = "Allow HTTP/HTTPS and SSH traffic"
  vpc_id      = aws_vpc.myvpc1.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-web-sg"
  }
}
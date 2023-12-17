terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
    region = var.AWS_REGION 
    profile = var.PROFILE 
}

# Create an AWS VPC. 
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/24"

   tags = {
    Name = "eval-2-vpc",
  }
}

# Create an internet gateway and associate it to the VPC.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "eval-2-igw",
  }
}

# Create one private subnet and one public subnet in the VPC.
resource "aws_subnet" "private-subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/26"
  
  tags = {
    Name = "eval-2-private-subnet",
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.64/26"
  
  tags = {
    Name = "eval-2-public-subnet",
  }
}

# Create a public route table routing 0.0.0.0/0 to the internet gateway.
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "eval-2-public-subnet",
  }
}

# Associate the public subnet to the public route table. 
resource "aws_route_table_association" "public-subnet-association" {
  subnet_id = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-route-table.id
}

# Create security groups for the subnets.
# Private subnet security group allows all incoming traffic from the public subnet security group. 
resource "aws_security_group" "private-subnet-sg" {
  name = "eval-2-private-subnet-sg"
  description = "Allow all incoming traffic from public subnet security group"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow all incoming traffic from public subnet security group"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = [aws_security_group.public-subnet-sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "eval-2-private-subnet-sg",
  }
}

# Public subnet security group allows incoming traffic on port 80 and 443 from 0.0.0.0/0 (public internet). 
resource "aws_security_group" "public-subnet-sg" {
  name = "eval-2-public-subnet-sg"
  description = "Allow all incoming traffic from on port 80 and 443 from 0.0.0.0/0 (public internet)"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http from public internet"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "https from public internet"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "eval-2-public-subnet-sg",
  }
}

# Database server.
# Create and launch an EC2 instance - e.g. Ubuntu 22.04 - into the private subnet created earlier.
# Download and install a database server in the EC2 instance - e.g. MySQL, PostgreSQL or MongoDB.
# Start and enable the database server service and ensure the database ports - e.g. 3306, 5432, etc. - are open and able to receive connections.
resource "aws_instance" "db-server" {
  ami = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.small"
  key_name = "lara-us-east-1"
  vpc_security_group_ids = [aws_security_group.private-subnet-sg.id]
  subnet_id = aws_subnet.private-subnet.id
  associate_public_ip_address = false
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install mysql-server -y
              sudo systemctl start mysql
              sudo systemctl enable mysql
              sudo ufw allow 3306 # mysql port
              EOF

  tags = {
    Name = "eval-2-db-server",
  }
}

# API server.
# Create and launch an EC2 instance - e.g. Ubuntu 22.04 - into the public subnet created earlier.
# Download and install packages for an API server.
# For example for a Python FastAPI API server:
# Python 3.10.
# fastapi python library.
# For MEAN stack NodeJS Express API server:
# Node 18
# Express library

resource "aws_instance" "api-server" {
  ami = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.small"
  key_name = "lara-us-east-1"
  vpc_security_group_ids = [aws_security_group.public-subnet-sg.id]
  subnet_id = aws_subnet.public-subnet.id
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install python3-pip -y
              sudo pip3 install fastapi uvicorn
              EOF

  tags = {
    Name = "eval-2-api-server",
  }
}

# Bonus - you can add the following components to your infrastructure but it is not mandatory.
# Autoscaling group.
# Application load balancer.
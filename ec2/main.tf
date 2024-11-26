provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "../vpc"  # Adjust the path to your VPC module
}

# Security group for backend EC2 instance
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]  # Allow traffic from the VPC
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Allow SSH from Bastion Host only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# Backend EC2 instance
resource "aws_instance" "backend" {
  ami               = "ami-0ea3c35c5c3284d82"
  instance_type     = "t2.micro"
  subnet_id         = module.vpc.private_subnet_therapy_id  # Reference private subnet from the VPC module
  security_groups   = [aws_security_group.backend_sg.id]
  associate_public_ip_address = false  # Disable public ip

  tags = {
    Name = "backend-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "Creating install_docker.sh script"
    cat << 'EOT' > /tmp/install_docker.sh
    #!/bin/bash
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 381414509815.dkr.ecr.us-east-1.amazonaws.com
    docker run -p 80:80 381414509815.dkr.ecr.us-east-1.amazonaws.com/devopstest:latest
    mkdir pace-equity-api
    cd pace-equity-api
    docker run hello
    echo "Docker installation and configuration completed"
    EOT

    # Give execute permission to the script
    sudo chmod +x /tmp/install_docker.sh

    # Execute the script with sudo
    sudo bash /tmp/install_docker.sh
    EOF
}

# Security group for bastion host
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (or restrict it to your IP)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Bastion host
resource "aws_instance" "bastion_host" {
  ami               = "ami-0ea3c35c5c3284d82"
  instance_type     = "t2.micro"
  subnet_id         = module.vpc.public_subnet_therapy_id  # Reference public subnet from the VPC module
  security_groups   = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-host"
  }
}

# Elastic IP for Bastion Host (optional)
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion_host.id

  tags = {
    Name = "bastion-eip"
  }
}

# Elastic IP for backend instance
resource "aws_eip" "backend_eip" {
  instance = aws_instance.backend.id

  tags = {
    Name = "backend-eip"
  }
}


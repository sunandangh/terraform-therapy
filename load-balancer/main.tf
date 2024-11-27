provider "aws" {
  region = "us-east-2"
}

# Reference the existing VPC directly to avoid duplicate creation
module "vpc" {
  source = "../vpc" # Ensure this is the VPC module from your previous configuration
}

module "ec2" {
  source = "../ec2"
}

# Security Group for Network Load Balancer (NLB)
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-security-group"
  description = "Security group for Network Load Balancer"
  vpc_id      = module.vpc.vpc_id # Reference the correct VPC

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }

  egress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
  }

  tags = {
    Name = "nlb-sg"
  }
}

# Network Load Balancer (NLB)
resource "aws_lb" "socket_nlb" {
  name               = "socket-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb_sg.id]
  subnets            = [module.vpc.public_subnet_therapy_id] # Using public subnet

  tags = {
    Name = "socket-nlb"
  }
}

# Target Group for the NLB
resource "aws_lb_target_group" "socket_tg" {
  name        = "socket-target-group"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    port     = "8080"
    protocol = "TCP"
  }

  tags = {
    Name = "socket-tg"
  }
}

# Listener for NLB
resource "aws_lb_listener" "socket_listener" {
  load_balancer_arn = aws_lb.socket_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.socket_tg.arn
  }
}

# Register EC2 Backend Instance with NLB
resource "aws_lb_target_group_attachment" "socket_tg_attachment" {
  target_group_arn = aws_lb_target_group.socket_tg.arn
  target_id        = module.ec2.backend_id
  port             = 8080
}

# Security Group for Application Load Balancer (ALB)
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id # Reference the correct VPC

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "api_alb" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [module.vpc.private_subnet_therapy_id]

  tags = {
    Name = "api-alb"
  }
}

# Target Group for the ALB
resource "aws_lb_target_group" "api_alb_tg" {
  name        = "api-alb-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    port     = "80"
    protocol = "HTTP"
  }

  tags = {
    Name = "api-alb-tg"
  }
}

# Listener for ALB
resource "aws_lb_listener" "api_alb_listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_alb_tg.arn
  }
}

# Register EC2 Backend Instance with ALB
resource "aws_lb_target_group_attachment" "api_alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.api_alb_tg.arn
  target_id        = module.ec2.backend_id
  port             = 80
}

output "nlb_arn" {
  description = "The ARN of the Network Load Balancer"
  value       = aws_lb.socket_nlb.arn
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.api_alb.arn
}

output "alb_security_group" {
  description = "The alb security group"
  value       = aws_security_group.alb_sg.id
}

output "nlb_security_group" {
  description = "The nlb security group"
  value       = aws_security_group.nlb_sg.id
}



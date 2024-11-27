provider "aws" {
  region = "us-east-2"
}

# Reference the VPC module once and use its outputs for ALB and NLB configurations
module "vpc" {
  source = "../vpc"  # Adjust the path to your VPC module
}

module "ec2" {
  source = "../ec2"
  
}

# 1. Security Group for NLB
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-security-group"
  description = "Security group for Network Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # Ingress rules: Allow traffic from CloudFront IP ranges
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # cidr_blocks = ["<cloudfront-ip-range>"]  # Replace with CloudFront IP ranges or 0.0.0.0/0 for unrestricted access
  }

  # Egress rules: Allow traffic to the backend instance
  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    # cidr_blocks = ["<backend-private-ip>"]  # Replace with the backend server's private IP
  }

  tags = {
    Name = "nlb-sg"
  }
}

# 2. Create the Network Load Balancer (NLB)
resource "aws_lb" "socket_nlb" {
  name               = "socket-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb_sg.id]
  subnets            = [module.vpc.public_subnet_therapy_id]  # Using public subnets from the VPC module

  tags = {
    Name = "socket-nlb"
  }
}

# 3. Create a Target Group for the Backend Container (NLB)
resource "aws_lb_target_group" "socket_tg" {
  name        = "socket-target-group"
  port        = 8080                      # Port the container listens on
  protocol    = "TCP"                     # NLB uses TCP protocol
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"                # Targets backend instance

  health_check {
    port     = "8080"
    protocol = "TCP"                      # TCP health check
  }

  tags = {
    Name = "socket-tg"
  }
}

# 4. Create a Listener for the NLB
resource "aws_lb_listener" "socket_listener" {
  load_balancer_arn = aws_lb.socket_nlb.arn
  port              = 443                 # HTTPS traffic from CloudFront
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.socket_tg.arn
  }
}

# 5. Register the Backend Instance as a Target (NLB)
resource "aws_lb_target_group_attachment" "socket_tg_attachment" {
  target_group_arn = aws_lb_target_group.socket_tg.arn
  target_id        = module.ec2.backend_id   # Attach backend EC2 instance
  port             = 8080                      # Port the container listens on
}

# 6. Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound traffic
  }

  tags = {
    Name = "alb-sg"
  }
}

# 7. Create the Application Load Balancer (ALB)
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

# 8. Create a Target Group for the Backend Container (ALB)
resource "aws_lb_target_group" "api_alb_tg" {
  name        = "api-alb-target-group"
  port        = 80                       # Port for the application (HTTP)
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"               # Targets backend instance

  health_check {
    port     = "80"
    protocol = "HTTP"
  }

  tags = {
    Name = "api-alb-tg"
  }
}

# 9. Create a Listener for the ALB
resource "aws_lb_listener" "api_alb_listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 80                 # HTTP traffic
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_alb_tg.arn
  }
}

# 10. Register the Backend Instance as a Target (ALB)
resource "aws_lb_target_group_attachment" "api_alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.api_alb_tg.arn
  target_id        = module.ec2.backend_id   # Attach backend EC2 instance
  port             = 80                        # Port for the application
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
  value = aws_security_group.alb_sg.id
  
}

output "nlb_security_group" {
  description = "The nlb security group"
  value = aws_security_group.nlb_sg.id
  
}
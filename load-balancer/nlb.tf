# 1. VPC and Subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block             = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

# 2. Network Load Balancer (NLB)
resource "aws_lb" "network_lb" {
  name               = "network-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

# 3. Target Group for NLB
resource "aws_lb_target_group" "network_lb_tg" {
  name     = "network-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}

# 4. Listener for NLB (TCP Listener)
resource "aws_lb_listener" "network_lb_tcp" {
  load_balancer_arn = aws_lb.network_lb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.network_lb_tg.arn
  }
}

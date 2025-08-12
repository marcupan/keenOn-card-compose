# Terraform configuration for keenOn-card-compose service

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # These values should be provided via terraform init -backend-config
    # bucket         = "keenon-terraform-state"
    # key            = "keenon-card-compose/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "keenon-terraform-locks"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-route-table"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for keenOn-card-compose application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 50052
    to_port     = 50052
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "gRPC access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-app-sg"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

# EC2 Instances
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.project_name}-deployer-key"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_instance" "app" {
  count                  = var.app_instance_count
  ami                    = var.app_ami
  instance_type          = var.app_instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "RUST_LOG=info" >> /etc/environment
              echo "SERVICE_PORT=50052" >> /etc/environment
              echo "ENCRYPTION_KEY=${var.encryption_key}" >> /etc/environment
              echo "OPENAI_API_KEY=${var.openai_api_key}" >> /etc/environment
              EOF

  tags = {
    Name        = "${var.project_name}-app-${count.index + 1}"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

# Load Balancer
resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-target-group"
  port     = 50052
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-target-group"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 50052
}

# S3 Bucket for backups
resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-backups-${var.environment}"

  tags = {
    Name        = "${var.project_name}-backups"
    Environment = var.environment
    Service     = "keenon-card-compose"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.app[0].id
  }
}

# Output
output "app_public_ips" {
  value = aws_instance.app[*].public_ip
}

output "load_balancer_dns" {
  value = aws_lb.app.dns_name
}

# Variables for keenOn-card-compose Terraform configuration

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project, used as a prefix for resource names"
  type        = string
  default     = "keenon-card-compose"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "The availability zones to deploy resources in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_instance_count" {
  description = "The number of EC2 instances to deploy"
  type        = number
  default     = 2
}

variable "app_ami" {
  description = "The AMI ID for the EC2 instances"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI in us-east-1
}

variable "app_instance_type" {
  description = "The instance type for the EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "The public SSH key for accessing the EC2 instances"
  type        = string
  sensitive   = true
}

variable "encryption_key" {
  description = "The encryption key for the application"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "The OpenAI API key for the application"
  type        = string
  sensitive   = true
  default     = ""
}

variable "backup_retention_days" {
  description = "The number of days to retain backups"
  type        = number
  default     = 30
}

variable "enable_https" {
  description = "Whether to enable HTTPS for the load balancer"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name for the application (if HTTPS is enabled)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

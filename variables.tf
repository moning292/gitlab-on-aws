variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access GitLab"
  type        = string
  default     = "0.0.0.0/0"
}

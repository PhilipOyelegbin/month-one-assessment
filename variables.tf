variable "aws_region" {
  type        = string
  description = "deployment region"
}

variable "project_name" {
  default     = "techcorp"
  type        = string
  description = "project name"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  type        = string
  description = "VPC CIDR block"
}

variable "subnet_cidr" {
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  type        = list(string)
  description = "List of subnet CIDR block"
}

variable "ami_details" {
  default = {
    owners = ["815818094689"],
    values = ["amzn2-x86_64-SQL_2019_Standard-2025.08.28"]
  }
  type = object({
    owners = list(string)
    values = list(string)
  })
  description = "AMI object details"
}

variable "instance_type" {
  type        = string
  description = "Instance type for EC2 instances"
}

variable "keypair_name" {
  type        = string
  description = "Key pair name for EC2 instances"
}

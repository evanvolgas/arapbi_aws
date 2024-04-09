variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
  default     = "Bastion host"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}
variable "region" {
  description = "The AWS region to deploy to"
  default     = "us-east-1"
}

variable "db_username" {
    description = "Username for interview prep postgres db"
    type = string
    sensitive = true
}

variable "db_password" {
    description = "Password for interview prep postgres db"
    type = string
    sensitive = true
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
    default = "10.0.0.0/16"
}

variable "subnet_a_cidr" {
    description = "CIDR block for subnet A"
    type = string
    default = "10.0.5.0/24"
}

variable "subnet_b_cidr" {
    description = "CIDR block for subnet B"
    type = string
    default = "10.0.6.0/24"
}

variable "db_subnet_a_cidr" {
    description = "CIDR block for DB subnet A"
    type = string
    default = "10.0.7.0/24"
}

variable "db_subnet_b_cidr" {
    description = "CIDR block for DB subnet B"
    type = string
    default = "10.0.8.0/24"
}

variable "availability_zone_a" {
    description = "Availability zone for subnet A"
    type = string
    default = "us-east-1a"
}

variable "availability_zone_b" {
    description = "Availability zone for subnet B"
    type = string
    default = "us-east-1b"
}

variable "alb_name" {
  description = "Name of the ALB.  Automatically adds \"-ALB\" to the end"
  type        = string
}

variable "asg_name" {
  description = "Name of the AutoScaling Group to Associate with CodeDeploy"
  type        = string
}

variable "ec2_allow_ips" {
  description = "IP(s) to allow direct SSH access to EC2 Instances (in private subnet)"
  type        = list
}

variable "environment" {
  description = "Tag for environment (default: Production)"
  default     = "Production"
  type        = string
}

variable "instance_type" {
  description = "Size of the EC2 Instance for AutoScaling (default: t3.small)"
  default     = "t3.small"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 SSH Key"
  type        = string
}

variable "private_subnets" {
  description = "Private Subnets for the ASG"
  type        = list
}

variable "public_subnets" {
  description = "Public Subnets for the ALB"
  type        = list
}

variable "region" {
  description = "The AWS Region to deploy the resources to"
  type        = string
}

variable "vpcid" {
  description = "ID of the VPC"
  type        = string
}

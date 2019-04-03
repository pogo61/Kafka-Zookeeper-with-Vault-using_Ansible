variable "access_key" {
  default = "missing"
  description = "The AWS user access key"
}

variable "secret_key" {
  default = "missing"
  description = "The AWS user secret key"
}

variable "terraform_role" {
  default = "<ARN for IAM Role predefined to allow Terraform to create everything>"
  description = "The AWS urole that terraform would use"
}


variable "region" {
  default = "eu-west-1"
  description = "The AWS region"
}

variable "k_subnet" {
  default = ""
  description = "subnet for housing kafka and zookeeper"
}

variable "kc_subnet" {
  default = ""
  description = "subnet for housing kafka connect"
}

variable "lt_vpc_cidr_block" {
  default = "10.0.0.0/16"
  description = "cidr block for Lounge Transaction vpc"
}

variable "man_vpc_cidr_block" {
  default = "11.0.0.0/16"
  description = "cidr block for Management vpc"
}

variable "kafka_subnet_cidr_blocks" {
  type = "list"
  default = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "kafka_connect_cidr_blocks" {
  type = "list"
  default = [
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24"
  ]
}

variable "bastion_cidr_blocks" {
  type = "list"
  default = [
    "11.0.11.0/24",
    "11.0.12.0/24",
    "11.0.13.0/24"
  ]
}

variable "kafka_ebs_vol_size" {
  default = 500
  description = "size of kafka ebs volumes in gigabytes"
}

variable "kafka_connect_ebs_vol_size" {
  default = 500
  description = "size of kafka connect ebs volumes in gigabytes"
}

variable "zookeeper_ebs_vol_size" {
  default = 500
  description = "size of zookeeper ebs volumes in gigabytes"
}

variable "kafka_ebs_vol_type" {
  default = "st1"
  description = "type of kafka ebs volumes"
}

variable "kafka_connect_ebs_vol_type" {
  default = "sc1"
  description = "type of kafka ebs volumes"
}

variable "zookeeper_ebs_vol_type" {
  default = "sc1"
  description = "type of kafka ebs volumes"
}

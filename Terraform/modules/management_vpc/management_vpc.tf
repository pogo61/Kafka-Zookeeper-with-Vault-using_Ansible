variable "availability_zones_names" {
  type = "list"
}

variable "man_vpc_cidr_block" {
}

resource "aws_vpc" "management_vpc" {
  cidr_block = "${var.man_vpc_cidr_block}"
  tags {
    Name = "management_vpc_id"
  }
}

// need to have a CIDR block for each availability zone for the vault subnets
variable "vault_cidr_blocks" {
  type  = "list"
  default = [
    "11.0.0.0/24",
    "11.0.1.0/24",
    "11.0.2.0/24"
  ]
}

// need to have a CIDR block for each availability zone for the management subnets
variable "management_cidr_blocks" {
  type  = "list"
  default = [
    "11.0.3.0/24",
    "11.0.4.0/24",
    "11.0.5.0/24"
  ]
}

resource "aws_subnet" "vault_subnet" {
  count		        = "${length(var.availability_zones_names)}"
  vpc_id            = "${aws_vpc.management_vpc.id}"
  availability_zone = "${var.availability_zones_names[count.index]}"
  cidr_block        = "${var.vault_cidr_blocks[count.index]}"
  #remove this when connect to this VPC via VPN or internal network
  map_public_ip_on_launch   = true
  tags {
    Name = "vault_subnet_az${count.index}"
  }
}

resource "aws_subnet" "management_subnet" {
  count		        = "${length(var.availability_zones_names)}"
  vpc_id            = "${aws_vpc.management_vpc.id}"
  availability_zone = "${var.availability_zones_names[count.index]}"
  cidr_block        = "${var.management_cidr_blocks[count.index]}"
  #remove this when connect to this VPC via VPN or internal network
  map_public_ip_on_launch   = true
  tags {
    Name = "management_subnet_az${count.index}"
  }
}

resource "aws_security_group" "management_sg" {
  vpc_id  = "${aws_vpc.management_vpc.id}"
  name    = "management-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "management_vpc_id" {
  value = "${aws_vpc.management_vpc.id}"
}

output "management_vpc_route_table_id" {
  value = "${aws_vpc.management_vpc.main_route_table_id}"
}

output "vault_subnet_ids" {
  value = "${aws_subnet.vault_subnet.*.id}"
}

output "management_subnet_ids" {
  value = "${aws_subnet.management_subnet.*.id}"
}

output "management_sg_id" {
  value = "${aws_security_group.management_sg.id}"
}

/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "management_vpc_ready" {
  value = "ready"
}


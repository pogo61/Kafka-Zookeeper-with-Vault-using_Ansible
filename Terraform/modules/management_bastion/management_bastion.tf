variable "availability_zones_names" {
  type = "list"
}

variable "ready" {
}

variable "man_main_route_table_id" {
}

variable "man_vpc_id" {
}


variable "bastion_cidr_blocks" {
  type = "list"
}

// This is for temporary internet access until the client has set up a VPN Server
// key generated from your predefined user allowed to assume the IAN role defined in main.tf - see ssh-keygen -y on https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws
resource "aws_key_pair" "admin" {
  key_name    = "admin-key"
  public_key   = "${var.admin-key}"
}

resource "aws_security_group" "bastion_sg" {
  vpc_id  = "${var.man_vpc_id}"
  name    = "bastion-sg"

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_subnet" "bastion_subnet" {
  count		                = "${length(var.availability_zones_names)}"
  vpc_id                    = "${var.man_vpc_id}"
  availability_zone         = "${var.availability_zones_names[count.index]}"
  cidr_block                = "${var.bastion_cidr_blocks[count.index]}"
  map_public_ip_on_launch   = true
  tags {
    Name = "bastion_subnet_az${count.index}"
  }
}

data "aws_ami" "management_bastion_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Bastion Host"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.account}"] # my account

}

resource "aws_instance" "management_bastion" {
  count		      = "${length(var.availability_zones_names)}"
  ami             = "${data.aws_ami.management_bastion_node.id}"
  instance_type   = "t2.micro"
  subnet_id 	  = "${aws_subnet.bastion_subnet.*.id[count.index]}"
  key_name        = "admin-key"
  security_groups = ["${aws_security_group.bastion_sg.id}"]
  user_data = <<-EOF
      #!/bin/bash
      sudo yum -y install awscli
      EOF
  tags {
    Name          = "management_bastion-${count.index}"
  }
}

resource "aws_internet_gateway" "management_bastion_gw" {
  vpc_id = "${var.man_vpc_id}"

  tags {
    Name = "management_bastion_gw"
  }
}

resource "aws_route" "management2internet" {
  route_table_id          = "${var.man_main_route_table_id}"
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = "${aws_internet_gateway.management_bastion_gw.id}"
}

output "bastion_subnet_ids" {
  value = "${aws_subnet.bastion_subnet.*.id}"
}

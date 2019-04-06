variable "lt_vpc_cidr_block" {
}

variable "kafka_subnet_cidr_blocks" {
  type = "list"
}

variable "kafka_connect_cidr_blocks" {
  type = "list"
}

variable "availability_zones_names" {
  type = "list"
}

resource "aws_vpc" "lounge_transactions_vpc" {
  cidr_block            = "${var.lt_vpc_cidr_block}"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  tags {
    Name                = "lounge_transactions_vpc"
  }
}

resource "aws_subnet" "kafka_subnet" {
  count		                = "${length(var.availability_zones_names)}"
  vpc_id                    = "${aws_vpc.lounge_transactions_vpc.id}"
  availability_zone         = "${var.availability_zones_names[count.index]}"
  cidr_block                = "${var.kafka_subnet_cidr_blocks[count.index]}"
  tags {
    Name = "kafka_subnet_az${count.index}"
  }
}

resource "aws_subnet" "kafka_connect_subnet" {
  count		                = "${length(var.availability_zones_names)}"
  vpc_id                    = "${aws_vpc.lounge_transactions_vpc.id}"
  availability_zone         = "${var.availability_zones_names[count.index]}"
  cidr_block                = "${var.kafka_connect_cidr_blocks[count.index]}"
  tags {
    Name                    = "kafka_connect_az${count.index}"
  }
}

resource "aws_subnet" "lounge_dmz" {
  vpc_id                    = "${aws_vpc.lounge_transactions_vpc.id}"
  availability_zone         = "${var.availability_zones_names[0]}"
  cidr_block                = "10.0.200.0/24"
  map_public_ip_on_launch   = true
  tags {
    Name                    = "lounge_dmz_subnet"
  }
}

resource "aws_internet_gateway" "lounge_transactions_gw" {
  vpc_id = "${aws_vpc.lounge_transactions_vpc.id}"

  tags {
    Name = "lounge_transactions_gw"
  }
}

resource "aws_route_table" "dmz" {
  vpc_id = "${aws_vpc.lounge_transactions_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.lounge_transactions_gw.id}"
  }

  tags {
    Name = "dmz"
  }
}
resource "aws_route_table_association" "lounge_transactions_nat" {
  subnet_id      = "${aws_subnet.lounge_dmz.id}"
  route_table_id = "${aws_route_table.dmz.id}"
}

resource "aws_eip" "lounge_transactions_nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "lounge_transactions_nat" {
  allocation_id = "${aws_eip.lounge_transactions_nat_eip.id}"
  subnet_id     = "${aws_subnet.lounge_dmz.id}"

  tags {
    Name = "lounge_transactions_nat"
  }
}

resource "aws_route" "transactions2internet" {
  route_table_id          = "${aws_vpc.lounge_transactions_vpc.main_route_table_id}"
  destination_cidr_block  = "0.0.0.0/0"
  nat_gateway_id          = "${aws_nat_gateway.lounge_transactions_nat.id}"
}

resource "aws_vpc_endpoint" "lounge_transactions_s3_endpoint" {
  vpc_id       = "${aws_vpc.lounge_transactions_vpc.id}"
  service_name = "com.amazonaws.eu-west-1.s3"
}

resource "aws_vpc_endpoint_route_table_association" "lounge_transactions_endpoint_association" {
  vpc_endpoint_id = "${aws_vpc_endpoint.lounge_transactions_s3_endpoint.id}"
  route_table_id  = "${aws_vpc.lounge_transactions_vpc.main_route_table_id}"
}

resource "aws_security_group" "lounge_transactions_sg" {
  vpc_id  = "${aws_vpc.lounge_transactions_vpc.id}"
  name    = "lounge_transactions-sg"

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

resource "aws_network_acl" "lounge_transactions_nacl" {
  vpc_id = "${aws_vpc.lounge_transactions_vpc.id}"
  subnet_ids = ["${concat(aws_subnet.kafka_subnet.*.id,aws_subnet.kafka_connect_subnet.*.id)}"]

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port   = 0
    to_port     = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port   = 0
    to_port     = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 200
    action     = "allow"
    cidr_block = "11.0.0.0/16"
    from_port   = 0
    to_port     = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port   = 0
    to_port     = 0
  }

  tags {
    Name = "lounge_transactions"
  }
}

output "lounge_transactions_vpc_id" {
  value = "${aws_vpc.lounge_transactions_vpc.id}"
}

output "lounge_availability_zones" {
  value = "${var.availability_zones_names}"
}

output "lounge_transactions_vpc_route_table_id" {
  value = "${aws_vpc.lounge_transactions_vpc.main_route_table_id}"
}

output "kafka_subnet_ids" {
  value = "${aws_subnet.kafka_subnet.*.id}"
}

output "kafka_connect_subnet_ids" {
  value = "${aws_subnet.kafka_connect_subnet.*.id}"
}

output "lounge_transactions_sg" {
  value = "${aws_security_group.lounge_transactions_sg.id}"
}
/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "transaction_vpc_ready" {
  value = "ready"
}

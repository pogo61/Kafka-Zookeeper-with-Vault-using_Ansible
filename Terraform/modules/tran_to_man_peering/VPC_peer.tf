variable "availability_zones_names" {
  type = "list"
}

variable "man_vpc_id" {
  default = ""
}

variable "tran_vpc_id" {
  default = ""
}

variable "tran_cidr_block" {
  default = ""
}

variable "man_main_route_table_id" {
  default = ""
}

variable "tran_main_route_table_id" {
  default = ""
}

variable "man_cidr_block" {
  default = ""
}

variable "man_bastion_subnet_ids" {
  type = "list"
}

variable "man_tools_subnet_ids" {
  type = "list"
}

variable "man_vault_subnet_ids" {
  type = "list"
}

variable "tran_kafka_subnet_ids" {
  type = "list"
}

variable "tran_kafka_connect_subnet_ids" {
  type = "list"
}

variable "readyt" {
}

variable "readym" {
}

resource "aws_vpc_peering_connection" "tran_man_vpc_peering" {
  peer_vpc_id   = "${var.tran_vpc_id}"
  vpc_id        = "${var.man_vpc_id}"
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = false
  }

  requester {
    allow_remote_vpc_dns_resolution = false
  }

  tags {
    Name = "VPC Peering between transaction and management"
  }
}

/**
 * Route rule.
 *
 * Creates a new route rule on the "primary" VPC main route table. All requests
 * to the "secondary" VPC's IP range will be directed to the VPC peering
 * connection.
 */
resource "aws_route" "transaction2management" {
  route_table_id = "${var.tran_main_route_table_id}"
  destination_cidr_block = "${var.man_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.tran_man_vpc_peering.id}"
}

resource "aws_route_table_association" "kafka" {
  count		     = "${length(var.availability_zones_names)}"
  subnet_id      = "${element(var.tran_kafka_subnet_ids, count.index)}"
  route_table_id = "${var.tran_main_route_table_id}"
}

resource "aws_route_table_association" "kafka_connect" {
  count		     = "${length(var.availability_zones_names)}"
  subnet_id      = "${element(var.tran_kafka_connect_subnet_ids, count.index)}"
  route_table_id = "${var.tran_main_route_table_id}"
}
/**
 * Route rule.
 *
 * Creates a new route rule on the "secondary" VPC main route table. All
 * requests to the "secondary" VPC's IP range will be directed to the VPC
 * peering connection.
 */
resource "aws_route" "management2transaction" {
  route_table_id = "${var.man_main_route_table_id}"
  destination_cidr_block = "${var.tran_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.tran_man_vpc_peering.id}"
}

resource "aws_route_table_association" "management_bastion" {
  count		     = "${length(var.availability_zones_names)}"
  subnet_id      = "${element(var.man_bastion_subnet_ids, count.index)}"
  route_table_id = "${var.man_main_route_table_id}"
}

resource "aws_route_table_association" "management_tools" {
  count		     = "${length(var.availability_zones_names)}"
  subnet_id      = "${element(var.man_tools_subnet_ids, count.index)}"
  route_table_id = "${var.man_main_route_table_id}"
}

resource "aws_route_table_association" "vault" {
  count		     = "${length(var.availability_zones_names)}"
  subnet_id      = "${element(var.man_vault_subnet_ids, count.index)}"
  route_table_id = "${var.man_main_route_table_id}"
}
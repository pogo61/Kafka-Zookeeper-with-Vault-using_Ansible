provider "aws" {
  access_key    = "${var.access_key}"
  secret_key    = "${var.secret_key}"
  region        = "${var.region}"
  assume_role {
    role_arn     = "${var.terraform_role}"
    session_name = "Terraform"
    external_id  = "Terraform"
  }
}

terraform {
  backend "s3" {
    bucket    = "<name for your state bucket>"
    key       = "terraform.tfstate"
    region    = "eu-west-1"
    role_arn  = "<ARN for IAM Role predefined to allow Terraform to create everything>"
    acl       = "private"
    encrypt   = true
  }
}

resource "aws_iam_role" "system_role" {
  name = "system_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<your account ID>:root"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "allow_all_policy" {
  name = "system_user_policy"
  role = "${aws_iam_role.system_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

data "aws_availability_zones" "available" {}

module "lounge_transactions_vpc" {
  source                      = "../../modules/lounge_transactions_vpc"
  lt_vpc_cidr_block           = "${var.lt_vpc_cidr_block}"
  kafka_subnet_cidr_blocks    = "${var.kafka_subnet_cidr_blocks}"
  kafka_connect_cidr_blocks   = "${var.kafka_connect_cidr_blocks}"
  availability_zones_names    = "${data.aws_availability_zones.available.names}"
}

module "zookeeper_ASG" {
  source                  = "../../modules/zookeeper_ASG"
  k_subnets               = "${module.lounge_transactions_vpc.kafka_subnet_ids}"
  az_list                 = "${module.lounge_transactions_vpc.lounge_availability_zones}"
  zookeeper_ebs_vol_size  = "${var.zookeeper_ebs_vol_size}"
  zookeeper_ebs_vol_type  = "${var.zookeeper_ebs_vol_type}"
  /*
  ** wait until transaction VPC creation is finished
  */
  ready                     = "${module.lounge_transactions_vpc.transaction_vpc_ready}"
  access_key                = "${var.access_key}"
  secret_key                = "${var.secret_key}"
  lounge_transaction_vpc_id = "${module.lounge_transactions_vpc.lounge_transactions_vpc_id}"
  lounge_sg_id              = "${module.lounge_transactions_vpc.lounge_transactions_sg}"
}

module "kafka_ASG" {
  source              = "../../modules/kafka_ASG"
  k_subnets           = "${module.lounge_transactions_vpc.kafka_subnet_ids}"
  az_list             = "${module.lounge_transactions_vpc.lounge_availability_zones}"
  kafka_ebs_vol_size  = "${var.kafka_ebs_vol_size}"
  kafka_ebs_vol_type  = "${var.kafka_ebs_vol_type}"
  lounge_sg_id        = "${module.lounge_transactions_vpc.lounge_transactions_sg}"
  /*
  ** wait until transaction VPC and Zookeeper ASG creation is finished
  */
  ready               = "${module.lounge_transactions_vpc.transaction_vpc_ready}"
  zkready             = "${module.zookeeper_ASG.zookeeper_ready}"
}

module "kafka_connect_ASG" {
  source                      = "../../modules/kafka_connect_ASG"
  k_connect_subnets           = "${module.lounge_transactions_vpc.kafka_connect_subnet_ids}"
  az_list                     = "${module.lounge_transactions_vpc.lounge_availability_zones}"
  kafka_connect_ebs_vol_size  = "${var.kafka_connect_ebs_vol_size}"
  kafka_connect_ebs_vol_type  = "${var.kafka_connect_ebs_vol_type}"
  lounge_sg_id                = "${module.lounge_transactions_vpc.lounge_transactions_sg}"
  /*
  ** wait until transaction VPC and Kafka ASG creation is finished
  */
  ready               = "${module.lounge_transactions_vpc.transaction_vpc_ready}"
  kready              = "${module.kafka_ASG.kafka_ready}"
}

module "management_vpc" {
  source              = "../../modules/management_vpc"
  man_vpc_cidr_block  = "${var.man_vpc_cidr_block}"
  availability_zones_names  = "${data.aws_availability_zones.available.names}"
}

module "management_ASG" {
  source              = "../../modules/management_ASG"
  subnets			  = "${module.management_vpc.management_subnet_ids}"
  az_list             = "${data.aws_availability_zones.available.names}"
  management_sg_id = "${module.management_vpc.management_sg_id}"
  management_ebs_vol_size  = "${var.zookeeper_ebs_vol_size}"
  management_ebs_vol_type  = "${var.zookeeper_ebs_vol_type}"
  /*
  ** wait until transaction VPC creation is finished
  */
  ready                     = "${module.management_vpc.management_vpc_ready}"
  access_key                = "${var.access_key}"
  secret_key                = "${var.secret_key}"
}

module "management_bastion" {
  source                    = "../../modules/management_bastion"
  availability_zones_names  = "${data.aws_availability_zones.available.names}"
  man_main_route_table_id   = "${module.management_vpc.management_vpc_route_table_id}"
  man_vpc_id                = "${module.management_vpc.management_vpc_id}"
  bastion_cidr_blocks       = "${var.bastion_cidr_blocks}"
  /*
  ** wait until management VPC creation is finished
  */
  ready                     = "${module.management_vpc.management_vpc_ready}"
}

module "consul_ASG" {
  source            = "../../modules/consul_ASG"
  subnets			= "${module.management_vpc.vault_subnet_ids}"
  region            = "${var.region}"
  access_key        = "${var.access_key}"
  secret_key        = "${var.secret_key}"
  management_vpc_id  = "${module.management_vpc.management_vpc_id}"
  system_role_arn = "${aws_iam_role.system_role.arn}"
  /*
  ** wait until management VPC creation is finished
  */
  ready             = "${module.management_vpc.management_vpc_ready}"
}

module "vault_ASG" {
  source                  = "../../modules/vault_ASG"
  subnets			      = "${module.management_vpc.vault_subnet_ids}"
  region                  = "${var.region}"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  management_sg_id        = "${module.management_vpc.management_sg_id}"
  system_role_arn         = "${aws_iam_role.system_role.arn}"
  consul_elb_name         = "${module.consul_ASG.consul_elb_name}"
  /*
  ** wait until Consul ASG creation is finished
  */
  consul_ready                     = "${module.consul_ASG.consul_ready}"
  /*
  ** wait until management VPC creation is finished
  */
  ready             = "${module.management_vpc.management_vpc_ready}"
}


module "transaction_to_management_peering" {
  source                    = "../../modules/tran_to_man_peering"
  availability_zones_names  = "${data.aws_availability_zones.available.names}"
  man_vpc_id                = "${module.management_vpc.management_vpc_id}"
  tran_vpc_id               = "${module.lounge_transactions_vpc.lounge_transactions_vpc_id}"
  man_cidr_block            = "${var.man_vpc_cidr_block}"
  tran_cidr_block           = "${var.lt_vpc_cidr_block}"
  man_main_route_table_id   = "${module.management_vpc.management_vpc_route_table_id}"
  tran_main_route_table_id  = "${module.lounge_transactions_vpc.lounge_transactions_vpc_route_table_id}"
  man_bastion_subnet_ids    = "${module.management_bastion.bastion_subnet_ids}"
  man_tools_subnet_ids      = "${module.management_vpc.management_subnet_ids}"
  man_vault_subnet_ids      = "${module.management_vpc.vault_subnet_ids}"
  tran_kafka_subnet_ids     = "${module.lounge_transactions_vpc.kafka_subnet_ids}"
  tran_kafka_connect_subnet_ids     = "${module.lounge_transactions_vpc.kafka_connect_subnet_ids}"
  /*
  ** wait until all VPC creation is finished
  */
  readyt                    = "${module.lounge_transactions_vpc.transaction_vpc_ready}"
  readym                    = "${module.management_vpc.management_vpc_ready}"
}
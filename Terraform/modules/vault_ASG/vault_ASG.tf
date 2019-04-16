resource "aws_dynamodb_table" "vault-state-table" {
  name           = "vault-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name        = "vault-state-table"
  }
}

data "aws_ami" "vault_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Vault Node"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.account}"] # my account
}

resource "aws_launch_configuration" "vault_ASG_launch" {
  image_id      = "${data.aws_ami.vault_node.id}"
  instance_type = "t2.micro"
  security_groups = ["${var.management_sg_id}"]
  key_name          = "admin-key"

  lifecycle {
    create_before_destroy = true
  }

  ebs_optimized = "${var.root_volume_ebs_optimized}"

  root_block_device {
    volume_type           = "${var.root_volume_type}"
    volume_size           = "${var.root_volume_size}"
    delete_on_termination = "${var.root_volume_delete_on_termination}"
  }

  user_data = "${data.template_file.user_data_vault_cluster.rendered}"
}

resource "aws_autoscaling_group" "vault_ASG" {
  depends_on = ["aws_dynamodb_table.vault-state-table"]
  vpc_zone_identifier		= ["${var.subnets}"]
  name                      = "vault_ASG"
  max_size                  = 5
  min_size                  = 3
  health_check_grace_period = 10
  health_check_type			= "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.vault_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "vault"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "vault_ASG_policy" {
  name                   = "vault_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = "${aws_autoscaling_group.vault_ASG.name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_vault_cluster" {
  template = "${file("${path.module}/user-data-vault.sh")}"

  vars {
    aws_region               = "${var.region}"
    s3_bucket_name           = "${var.s3_bucket_name}"
    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
    consul_cluster_tag_value = "${var.consul_cluster_value}"
    consul_elb_name          = "${var.consul_elb_name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "vault_ASG_alarm" {
  alarm_name          = "vault_ASG_80_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.vault_ASG.name}"
  }

  alarm_description = "This metric monitors vault ASG cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.vault_ASG_policy.arn}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET TO USE AS A STORAGE BACKEND
# Also, add an IAM role policy that gives the Vault servers access to this S3 bucket
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vault_storage" {
  bucket        = "${var.s3_bucket_name}"
  force_destroy = "${var.force_destroy_s3_bucket}"

  tags {
    Description = "Used for secret storage with Vault. DO NOT DELETE this Bucket unless you know what you are doing."
  }
}

resource "aws_s3_bucket_policy" "kafka_bucket_policy" {
  bucket = "${aws_s3_bucket.vault_storage.id}"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowList",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${var.system_role_arn}"
        },
        "Action": "s3:*",
        "Resource": [
            "${aws_s3_bucket.vault_storage.arn}",
            "${aws_s3_bucket.vault_storage.arn}/*"
        ]
      }
    ]
  }
  POLICY
}
data "aws_ami" "kafka_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["kafka-RHEL-linux-74*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["<your account ID>"] # my account

}

/*resource "aws_s3_bucket" "kafka_bucket" {
  bucket = "kafka-bucket-pp"
  acl    = "bucket-owner-full-control"
  force_destroy = true

  tags {
    Name        = "kafka-bucket"
  }
}

resource "aws_s3_bucket_policy" "kafka_bucket_policy" {
  bucket = "${aws_s3_bucket.kafka_bucket.id}"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowList",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::095955279155:role/Terraform"
        },
        "Action": "s3:*",
        "Resource": [
            "arn:aws:s3:::kafka-bucket-pp",
            "arn:aws:s3:::kafka-bucket-pp*//*"
        ]
      }
    ]
  }
  POLICY
}*/

resource "aws_dynamodb_table" "kafka-state-table" {
  name           = "kafka-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name        = "kafka-state-table"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_kafka_cluster" {
  template = "${file("${path.module}/user-data-kafka.sh")}"

}

resource "aws_launch_configuration" "kafka_ASG_launch" {
  depends_on = ["aws_dynamodb_table.kafka-state-table"]
  image_id      = "${data.aws_ami.kafka_node.id}"
  instance_type = "t2.medium"
  security_groups = ["${var.lounge_sg_id}"]
  key_name          = "admin-key"

  lifecycle {
    create_before_destroy = true
  }

  user_data = "${data.template_file.user_data_kafka_cluster.rendered}"
//  user_data = <<-EOF
//      #!/bin/bash -ex
//      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
//      echo BEGIN
//      # wait for the zookeeper cluster to complete setup
//      sleep 30
//      su ec2-user -c 'source ~/.bash_profile; python /tmp/install-kafka/conf_kafka.py'
//      echo END
//      EOF
}

resource "aws_autoscaling_group" "kafka_ASG" {
  vpc_zone_identifier		= ["${var.k_subnets}"]
  name                      = "kafka_ASG"
  max_size                  = 5
  min_size                  = 5
  health_check_grace_period = 10
  health_check_type			= "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.kafka_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "kafka"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "kafka_ASG_policy" {
  name                   = "kafka_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.kafka_ASG.name}"
}

resource "aws_cloudwatch_metric_alarm" "kafka_ASG_alarm" {
  alarm_name          = "kafka_ASG_over_100_write_ops_per_minute"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "DiskWriteOps"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "100"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.kafka_ASG.name}"
  }

  alarm_description = "This metric monitors kafka ASG write operations"
  alarm_actions     = ["${aws_autoscaling_policy.kafka_ASG_policy.arn}"]
}

/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "kafka_ready" {
  value = "ready"
}

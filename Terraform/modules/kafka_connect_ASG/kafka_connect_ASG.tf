resource "aws_dynamodb_table" "kafka_connect-state-table" {
  name           = "kafka_connect-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name        = "kafka_connect-state-table"
  }
}

data "aws_ami" "kafka_connect_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["kafka_connect-RHEL-linux-74*"]
//    values = ["Kafka_Connect-Amazon Linux AMI*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["<your account ID>"] # my account

}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_kc_cluster" {
  template = "${file("${path.module}/user-data-kafka_connect.sh")}"

}

resource "aws_launch_configuration" "kafka_connect_ASG_launch" {
  depends_on = ["data.aws_ami.kafka_connect_node"]
  image_id      = "${data.aws_ami.kafka_connect_node.id}"
  instance_type = "t2.medium"
  security_groups = ["${var.lounge_sg_id}"]
  key_name          = "admin-key"

  lifecycle {
    create_before_destroy = true
  }

  user_data = "${data.template_file.user_data_kc_cluster.rendered}"
}

resource "aws_autoscaling_group" "kafka_connect_ASG" {
  vpc_zone_identifier		= ["${var.k_connect_subnets}"]
  name                      = "kafka_connect_ASG"
  max_size                  = 3
  min_size                  = 3
  health_check_grace_period = 10
  health_check_type			= "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.kafka_connect_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "kafka_connect"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "kafka_connect_ASG_policy" {
  name                   = "kafka_connect_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.kafka_connect_ASG.name}"
}

resource "aws_cloudwatch_metric_alarm" "kafka_connect_ASG_alarm" {
  alarm_name          = "kafka_connect_ASG_70_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.kafka_connect_ASG.name}"
  }

  alarm_description = "This metric monitors kafka connect ASG write operations"
  alarm_actions     = ["${aws_autoscaling_policy.kafka_connect_ASG_policy.arn}"]
}
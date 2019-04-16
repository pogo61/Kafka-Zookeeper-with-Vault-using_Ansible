variable "k_subnets" {
  type = "list"
}

variable "az_list"{
  type = "list"
}

variable "zookeeper_ebs_vol_size" {
}

variable "zookeeper_ebs_vol_type" {
}

variable "ready" {
}

variable "access_key" {
}

variable "secret_key" {
}

variable "lounge_transaction_vpc_id" {
}

variable "lounge_sg_id"{
}

data "aws_ami" "zookeeper_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Zookeeper Node"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.account}"] # my account
}

resource "aws_launch_configuration" "zookeeper_ASG_launch" {
  image_id      = "${data.aws_ami.zookeeper_node.id}"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "${var.zookeeper_ebs_vol_type}"
    volume_size = "${var.zookeeper_ebs_vol_size}"
  }

  key_name          = "admin-key"
  security_groups   = ["${aws_security_group.zookeeper_sg.id}"]

  user_data = <<-EOF
      #!/bin/bash -ex
      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
      echo BEGIN
      su ec2-user -c 'source ~/.bash_profile; python /tmp/install-zookeeper/conf_zookeeper.py'
      echo END
      EOF
}

resource "aws_security_group" "zookeeper_sg" {
  name = "zookeeper-sg"
  vpc_id = "${var.lounge_transaction_vpc_id}"

  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    from_port   = 2888
    to_port     = 2888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3888
    to_port     = 3888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_dynamodb_table" "zookeeper-state-table" {
  name           = "zookeeper-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name        = "zookeeper-state-table"
  }
}

resource "aws_autoscaling_group" "zookeeper_ASG" {
  depends_on = ["aws_dynamodb_table.zookeeper-state-table"]
  vpc_zone_identifier		= ["${var.k_subnets}"]
  name                      = "zookeeper_ASG"
  max_size                  = 3
  min_size                  = 3
  health_check_grace_period = 10
  health_check_type			= "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.zookeeper_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "zookeeper"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "zookeeper_ASG_policy" {
  name                   = "zookeeper_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = "${aws_autoscaling_group.zookeeper_ASG.name}"
}

resource "aws_cloudwatch_metric_alarm" "zookeeper_ASG_alarm" {
  alarm_name          = "zookeeper_ASG_80_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.zookeeper_ASG.name}"
  }

  alarm_description = "This metric monitors zookeeper ASG cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.zookeeper_ASG_policy.arn}"]
}

/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "zookeeper_ready" {
  value = "ready"
}
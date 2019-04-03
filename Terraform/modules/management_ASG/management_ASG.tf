variable "subnets" {
  type = "list"
}

variable "az_list"{
  type = "list"
}

variable "management_ebs_vol_size" {
}

variable "management_ebs_vol_type" {
}

variable "ready" {
}

variable "access_key" {
}

variable "secret_key" {
}

variable "management_sg_id"{
}

data "aws_ami" "management_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Management-Amazon Linux AMI*"]
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
data "template_file" "user_data_management_cluster" {
  template = "${file("${path.module}/user-data-management.sh")}"

}

resource "aws_launch_configuration" "management_ASG_launch" {
  image_id      = "${data.aws_ami.management_node.id}"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "${var.management_ebs_vol_type}"
    volume_size = "${var.management_ebs_vol_size}"
  }

  key_name          = "admin-key"
  security_groups   = ["${var.management_sg_id}"]

  user_data = "${data.template_file.user_data_management_cluster.rendered}"
//  user_data = <<-EOF
//      #!/bin/bash -ex
//      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
//      echo BEGIN
//      # wait for the zookeeper and kafka clusters to complete setup
//      sleep 180
//      su ec2-user -c 'source ~/.bash_profile; python /tmp/install-tools/conf_tools.py'
//      su ec2-user -c 'source ~/.bash_profile; /usr/local/bin/docker-compose -f /tmp/install-tools/zoonavigator-docker-compose.yml up -d'
//      su ec2-user -c 'source ~/.bash_profile; /usr/local/bin/docker-compose -f /tmp/install-tools/kafka-manager-docker-compose.yml up -d'
//      echo END
//      EOF
}

resource "aws_dynamodb_table" "management-state-table" {
  name           = "management-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name = "management-state-table"
  }
}

resource "aws_autoscaling_group" "management_ASG" {
  depends_on = ["aws_dynamodb_table.management-state-table"]
  vpc_zone_identifier		= ["${var.subnets}"]
  name                      = "management_ASG"
  max_size                  = 3
  min_size                  = 3
  health_check_grace_period = 10
  health_check_type			= "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.management_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "management"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "management_ASG_policy" {
  name                   = "management_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = "${aws_autoscaling_group.management_ASG.name}"
}

resource "aws_cloudwatch_metric_alarm" "management_ASG_alarm" {
  alarm_name          = "management_ASG_80_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.management_ASG.name}"
  }

  alarm_description = "This metric monitors management ASG cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.management_ASG_policy.arn}"]
}

/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "management_ready" {
  value = "ready"
}
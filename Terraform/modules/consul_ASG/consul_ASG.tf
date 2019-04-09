resource "aws_dynamodb_table" "consul-state-table" {
  name           = "consul-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "state_name"

  attribute {
    name = "state_name"
    type = "S"
  }

  tags {
    Name        = "consul-state-table"
  }
}

# Consul elb
resource "aws_elb" "consul_elb" {
  name               = "consul-elb"
  subnets            = ["${var.subnets}"]
  internal           = true
  security_groups    = ["${aws_security_group.consul_sg.id}"]

  listener {
    instance_port     = 8300
    instance_protocol = "http"
    lb_port           = 8300
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8400
    instance_protocol = "http"
    lb_port           = 8400
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8500
    instance_protocol = "http"
    lb_port           = 8500
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8600
    instance_protocol = "http"
    lb_port           = 8600
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8301
    instance_protocol = "http"
    lb_port           = 8301
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8302
    instance_protocol = "http"
    lb_port           = 8302
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 30
  }

  tags {
    Name = "consul-elb"
  }
}

data "aws_ami" "consul_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Console Node"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${var.account}"] # my account
}

### Creating Security Group for consul cluster
resource "aws_security_group" "consul_sg" {
  name = "terraform-example-instance"
  vpc_id  = "${var.management_vpc_id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8300
    to_port = 8300
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8400
    to_port = 8400
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8600
    to_port = 8600
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8301
    to_port = 8301
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8302
    to_port = 8302
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["11.0.0.0/8"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "consul_ASG_launch" {
  image_id      = "${data.aws_ami.consul_node.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.consul_sg.id}"]
  key_name          = "admin-key"

  lifecycle {
    create_before_destroy = true
  }

  user_data = "${data.template_file.user_data_consul_cluster.rendered}"
}

resource "aws_autoscaling_group" "consul_ASG" {
  depends_on = ["aws_dynamodb_table.consul-state-table"]
  vpc_zone_identifier		= ["${var.subnets}"]
  name                      = "${local.cluster_value}"
  max_size                  = 5
  min_size                  = 3
  health_check_grace_period = 10
  health_check_type			= "ELB"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.consul_ASG_launch.name}"
  tag {
    key                 = "Name"
    value               = "consul"
    propagate_at_launch = true
  }
/*  tag {
    key                 = "${local.cluster_name}"
    value               = "${local.cluster_value}"
    propagate_at_launch = true
  }*/
}

# Attach ASG to elb
resource "aws_autoscaling_attachment" "consul_asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.consul_ASG.id}"
  elb                    = "${aws_elb.consul_elb.id}"
}

resource "aws_autoscaling_policy" "consul_ASG_policy" {
  name                   = "consul_ASG_add_one_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = "${aws_autoscaling_group.consul_ASG.name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_consul_cluster" {
  template = "${file("${path.module}/user-data-consul.sh")}"

  vars {
    aws_region               = "${var.region}"
    s3_bucket_name           = "${var.s3_bucket_name}"
    consul_cluster_tag_key   = "${local.cluster_name}"
    consul_cluster_tag_value = "${local.cluster_value}"
  }
}

resource "aws_cloudwatch_metric_alarm" "consul_ASG_alarm" {
  alarm_name          = "consul_ASG_80_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.consul_ASG.name}"
  }

  alarm_description = "This metric monitors consul ASG cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.consul_ASG_policy.arn}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET TO USE AS A STORAGE BACKEND
# Also, add an IAM role policy that gives the Vault servers access to this S3 bucket
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "consul_storage" {
  bucket        = "${var.s3_bucket_name}"
  force_destroy = "${var.force_destroy_s3_bucket}"

  tags {
    Description = "Used for secret storage with Vault. DO NOT DELETE this Bucket unless you know what you are doing."
  }
}

resource "aws_s3_bucket_policy" "consul_bucket_policy" {
  bucket = "${aws_s3_bucket.consul_storage.id}"
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
            "${aws_s3_bucket.consul_storage.arn}",
            "${aws_s3_bucket.consul_storage.arn}/*"
        ]
      }
    ]
  }
  POLICY
}

/*
** used to add dependencies for modules
** the all dependent modules wont run in parrallel but wait for this to finish
*/
output "consul_ready" {
  value = "ready"
}
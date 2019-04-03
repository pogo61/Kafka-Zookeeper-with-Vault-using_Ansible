output "s3_bucket_arn" {
  value = "${aws_s3_bucket.consul_storage.arn}"
}

output "consul_elb_name" {
  value = "${aws_elb.consul_elb.name}"
}

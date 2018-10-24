module "alertmanager" {
    source                        = "./service-internal"
    name                          = "alertmanager"
    ecs_cluster_name              = "${var.ecs_cluster_name}"
    aws_region                    = "${var.aws_region}"
    desired_count                 = "1"
    security_groups               = ["${aws_security_group.service.id}", "${aws_security_group.alertmanager.id}"]
    allowed_subnets               = ["${aws_subnet.internal.*.id}"]
    namespace                     = "${var.namespace}"
    namespace_id                  = "${aws_service_discovery_private_dns_namespace.openfaas.id}"
    task_image                    = "ewilde/alertmanager"
    task_image_version            = "v0.15.1"
    task_role_arn                 = "${aws_iam_role.alertmanager_role.arn}"
    task_ports                    = "[{\"containerPort\":9093,\"hostPort\":9093}]"
    task_command                  = <<CMD
[
    "--config.file=/alertmanager.yml",
    "--storage.path=/alertmanager'"
]
CMD
}

resource "aws_security_group" "alertmanager" {
    name = "${var.namespace}.alertmanager"
    description = "alertmanager security group."
    vpc_id = "${aws_vpc.default.id}"

    tags {
        Name = "${format("%s-alertmanager", var.namespace)}"
    }
}

resource "aws_security_group_rule" "alertmanager_ingress_alertmanager" {
    type                     = "ingress"
    security_group_id        = "${aws_security_group.alertmanager.id}"
    source_security_group_id = "${aws_security_group.prometheus.id}"
    from_port                = 9093
    to_port                  = 9093
    protocol                 = "tcp"
}

resource "aws_security_group_rule" "alertmanager_egress_gateway" {
    type                     = "egress"
    security_group_id        = "${aws_security_group.alertmanager.id}"
    source_security_group_id = "${aws_security_group.gateway.id}"
    from_port                = 8080
    to_port                  = 8080
    protocol                 = "tcp"
}

resource "aws_iam_role" "alertmanager_role" {
    name = "${var.namespace}-alertmanager-provider-role"
    assume_role_policy = "${file("${path.module}/data/iam/ecs-task-assumerole.json")}"
}

resource "aws_iam_role_policy" "alertmanager_role_policy" {
    name = "${var.namespace}-alertmanager-role-policy"
    role = "${aws_iam_role.alertmanager_role.id}"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    ${file("${path.module}/data/iam/log-policy.json")}
  ]
}
EOF
}

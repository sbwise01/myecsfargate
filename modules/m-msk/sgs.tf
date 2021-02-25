resource "aws_security_group" "security_group" {
  name        = "${local.cluster_name}-sg"
  description = "msk security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = format("%s", "${local.cluster_name}-sg")
    },
  )
}

resource "aws_security_group_rule" "default_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "msk_ingress_rule" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.security_group.id
  source_security_group_id = aws_security_group.security_group.id
}

resource "aws_security_group_rule" "ecs_ingress_rule" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.security_group.id
  source_security_group_id = var.ecs_ingress_sg_id
}

resource "aws_security_group_rule" "vpc_ssh_ingress_rule" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  security_group_id        = aws_security_group.security_group.id
  cidr_blocks              = [var.cidr_range]
}

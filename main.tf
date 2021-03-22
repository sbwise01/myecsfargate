terraform {
  required_version = "~> 0.12.30"

  backend "s3" {
    bucket = "brad-terraform-state-us-east-1"
    key    = "ecsfargate.tfstate"
    region = "us-east-1"
    profile = "supportfog"
  }
}

data "aws_caller_identity" "current" {}

data "template_file" "ecs_container_definition" {
  template = file("./base.tpl")
  vars = {
    name     = var.tag_name
    image    = "sbwise/flaskhelloworld:0.1.0"
    region   = "us-east-1"
    loggroup = aws_cloudwatch_log_group.awslogs-ecs-fargate-sumo.name
  }
}

data "aws_route53_zone" "zone" {
  name         = "superscalability.com."
}

provider "aws" {
  region  = "us-east-1"
  profile = "supportfog"
  version = "~> 3.27"
}

resource "aws_key_pair" "main" {
  key_name_prefix = "ecskey"
  public_key      = file("~/.ssh/id_rsa.pub")
}

resource "aws_route53_record" "ecs_task" {
  name    = var.tag_name
  type    = "A"
  zone_id = data.aws_route53_zone.zone.zone_id
  alias {
    evaluate_target_health = false
    name                   = aws_alb.ecs_lb.dns_name
    zone_id                = aws_alb.ecs_lb.zone_id
  }
}

module "ecs" {
  source = "git@github.com:FoghornConsulting/m-ecs?ref=dhelmick/fargate-addition"
  name       = var.tag_name
  subnet_ids = module.aws_vpc.subnets.private.*.id
  key_name   = aws_key_pair.main.key_name

  host_append_script = <<EOF
echo 'ECS_ENGINE_AUTH_TYPE=docker' >> /etc/ecs/ecs.config

echo 'ECS_ENGINE_AUTH_DATA={"${var.ecs_url}":{"username":"${var.ecs_username}","password":"${var.ecs_password}","email":"${var.ecs_email}"}}' >> /etc/ecs/ecs.config

docker login -u "${var.ecs_username}" -p "${var.ecs_password}"
EOF
}

resource "aws_cloudwatch_log_group" "awslogs-ecs-fargate-sumo" {
  name = "awslogs-ecs-fargate-sumo"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  path               = "/ecsservices/"
  assume_role_policy = data.aws_iam_policy_document.ecs-task-assume-policy.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs-task-assume-policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "${var.tag_name}-flaskhelloworld"
  container_definitions    = data.template_file.ecs_container_definition.rendered
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "ecs_service" {
  name                  = "${var.tag_name}-flaskhelloworld"
  cluster               = var.tag_name
  task_definition       = aws_ecs_task_definition.ecs_task.arn
  desired_count         = 2
  launch_type           = "FARGATE"

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs_lb_tg.arn
    container_name   = var.tag_name
    container_port   = "5000"
  }

  network_configuration {
    security_groups = list(aws_security_group.ecs_task.id)
    subnets         = module.aws_vpc.subnets.private.*.id
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "ecs_service_autoscaling_target" {
  max_capacity       = 400
  min_capacity       = 2
  resource_id        = "service/${var.tag_name}/${var.tag_name}-flaskhelloworld"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_service_autoscaling_policy" {
  name               = "${var.tag_name}-flaskhelloworld-scaling-policy"
  resource_id        = aws_appautoscaling_target.ecs_service_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service_autoscaling_target.service_namespace
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1 # scale in slower than scale out
    }

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 2 # scale out fast, this is a high throughput consumer
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_service_autoscaling_alarm" {
  alarm_name          = "${var.tag_name}-flaskhelloworld-autoscaling-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "3"

  dimensions = {
    TargetGroup = aws_alb_target_group.ecs_lb_tg.arn_suffix
    LoadBalancer = aws_alb.ecs_lb.arn_suffix
  }

  alarm_description = "This metric monitors load balancer request count per target of ecs_service flaskhelloworld tasks"
  alarm_actions     = [aws_appautoscaling_policy.ecs_service_autoscaling_policy.arn]
  ok_actions        = [aws_appautoscaling_policy.ecs_service_autoscaling_policy.arn]
}

resource "aws_security_group" "ecs_task" {
  name_prefix = "${var.tag_name}-flaskhelloworld"
  vpc_id      = module.aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ecs_task_lb_ingress" {
  type                     = "ingress"
  from_port                = "0"
  to_port                  = "65535"
  protocol                 = "all"
  source_security_group_id = aws_security_group.lb.id
  security_group_id        = aws_security_group.ecs_task.id
}

resource "aws_security_group_rule" "ecs_task_egress" {
  type              = "egress"
  from_port         = "0"
  to_port           = "65535"
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_task.id
}

resource "aws_security_group" "lb" {
  name_prefix = "${var.tag_name}-lb"
  vpc_id      = module.aws_vpc.vpc.id
}

resource "aws_security_group_rule" "lb_ingress" {
  type = "ingress"

  from_port   = "80"
  to_port     = "80"
  protocol    = "all"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "lb_egress" {
  type                     = "egress"
  from_port                = "0"
  to_port                  = "65535"
  protocol                 = "all"
  source_security_group_id = aws_security_group.ecs_task.id
  security_group_id        = aws_security_group.lb.id
}

resource "aws_alb" "ecs_lb" {
  name_prefix                = "ecs"
  load_balancer_type         = "application"
  security_groups            = list(aws_security_group.lb.id)
  subnets                    = module.aws_vpc.subnets.public.*.id
  enable_deletion_protection = false
  tags                       = {
    CostCenter  = var.tag_costcenter
    Name        = var.tag_name
    Environment = var.tag_environment
  }
}

resource "aws_alb_listener" "ecs_lb_listener" {
  load_balancer_arn = aws_alb.ecs_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.ecs_lb_tg.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "ecs_lb_tg" {
  name_prefix = "ecs"
  vpc_id      = module.aws_vpc.vpc.id
  protocol    = "HTTP"
  port        = 5000
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/"
    port                = 5000
    protocol            = "HTTP"
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

module "aws_vpc" {
  source = "git@github.com:FoghornConsulting/m-vpc?ref=v1.2.0"

  tag_map = {
    CostCenter  = var.tag_costcenter
    Name        = var.tag_name
    Environment = var.tag_environment
  }

  subnet_map = {
    public   = 3
    private  = 3
    isolated = 3
  }
}

module "msk" {
  source                              = "./modules/m-msk"
  cluster_name                        = "${var.tag_name}-msk"
  broker_node_client_subnets          = module.aws_vpc.subnets.private.*.id
  broker_node_instance_type           = "kafka.m5.xlarge"
  number_of_broker_nodes              = "3"
  kafka_version                       = "2.2.1"
  ecs_ingress_sg_id                   = aws_security_group.ecs_task.id
  tags                                = {
    CostCenter  = var.tag_costcenter
    Name        = var.tag_name
    Environment = var.tag_environment
  }
  cidr_range                          = module.aws_vpc.vpc.cidr_block
  vpc_id                              = module.aws_vpc.vpc.id
  server_properties = [
    "auto.create.topics.enable=true",
    "default.replication.factor=3",
    "min.insync.replicas=2",
    "num.io.threads=8",
    "num.network.threads=5",
    "num.partitions=10",
    "num.replica.fetchers=2",
    "socket.request.max.bytes=104857600",
    "delete.topic.enable=true",
    "unclean.leader.election.enable=true"
  ]
}

variable "ecs_url" {}
variable "ecs_username" {}
variable "ecs_password" {}
variable "ecs_email" {}

variable "tag_costcenter" {
  default = "brad@foghornconsulting.com"
}

variable "tag_environment" {
  default = "Staging"
}

variable "tag_name" {
  default = "bradecs"
}

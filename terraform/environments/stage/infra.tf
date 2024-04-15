data "terraform_remote_state" "ecs_infra" {
  backend = "s3"

  config = {
    bucket         = "df-terraform-nonprod"
    key            = "environments/stage/ecs-infra-stage.tf"
    region         = "us-east-1"
    dynamodb_table = "df-terraform-nonprod-lock-db"
  }
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = data.terraform_remote_state.ecs_infra.outputs.ecs_infrastructure
}

output "cluster_id" {
  description = "ARN of the Load Balancer"
  value       = data.terraform_remote_state.ecs_infra.outputs.cluster_id
}

output "stage_vpc_id" {
  value = data.terraform_remote_state.ecs_infra.outputs.vpc_id
}

output "stage_public_subnets" {
  value = data.terraform_remote_state.ecs_infra.outputs.public_subnets
}

output "stage_private_subnets" {
  value = data.terraform_remote_state.ecs_infra.outputs.private_subnets
}

output "load_balancer_arn" {
  description = "ARN of the Load Balancer"
  value       = data.terraform_remote_state.ecs_infra.outputs.lb_arn
}

output "ecs-service-role" {
  description = "ARN of the Load Balancer"
  value       = data.terraform_remote_state.ecs_infra.outputs.ecs-service-role-arn
}

output "lb-security-group-id" {
  description = "id of the load lalancer sg"
  value       = data.terraform_remote_state.ecs_infra.outputs.lb_security_group_id
}

output "default_tags" {
  description = "id of the load lalancer sg"
  value       = data.terraform_remote_state.ecs_infra.outputs.default_tags
}

output "listener_80_arn" {
  description = "id of the load lalancer sg"
  value       = data.terraform_remote_state.ecs_infra.outputs.listener_80_arn
}




resource "aws_security_group" "service-sg" {
  name        = "${var.app_services.name}-sg"
  description = "Allow HTTP and HTTPS traffic inbound"
  vpc_id      = data.terraform_remote_state.ecs_infra.outputs.vpc_id

  tags = merge(
    {
      "Name"        = "${data.terraform_remote_state.ecs_infra.outputs.ecs_infrastructure}-sg-alb",
      "Environment" = "stage"
    },
    data.terraform_remote_state.ecs_infra.outputs.default_tags
  )
}

# tfsec:ignore:AVD-AWS-0107 -- Allow unrestricted ingress on port 80 from a specific security group
resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  description       = "Port 80 HTTP"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.service-sg.id

  # Specify the source security group ID instead of CIDR blocks
  source_security_group_id = data.terraform_remote_state.ecs_infra.outputs.lb_security_group_id
}

# tfsec:ignore:AVD-AWS-0104 -- Allow unrestricted egress to the internet
resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  description       = "Allow egress to internet"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.service-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]

}

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_services.ecs_task_family
  network_mode             =  var.app_services.network_mode
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.terraform_remote_state.ecs_infra.outputs.ecs-service-role-arn
  cpu                      =  var.app_services.ecs_task_cpu
  memory                   =  var.app_services.ecs_task_memory

  container_definitions = jsonencode([{
    name  = var.app_services.name
    image = var.ecs_task_container_image
    essential = true
    portMappings = [{
      containerPort = var.app_services.ecs_task_container_port
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = var.app_services.name
  cluster         = data.terraform_remote_state.ecs_infra.outputs.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.terraform_remote_state.ecs_infra.outputs.private_subnets
    security_groups = [aws_security_group.service-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = var.ecs_task_container_image
    container_port   = var.app_services.ecs_task_container_port
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.ecs_infra.outputs.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "public_listener_rule" {
  listener_arn = data.terraform_remote_state.ecs_infra.outputs.listener_80_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  condition {
    path_pattern {
      values = ["/mews"]
    }
  }
}

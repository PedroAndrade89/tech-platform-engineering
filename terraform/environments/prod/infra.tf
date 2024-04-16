data "terraform_remote_state" "ecs_infra" {
  backend = "s3"

  config = {
    bucket         = "df-terraform-nonprod"
    key            = "environments/prod/ecs-infra-prod.tf"
    region         = "us-east-1"
    dynamodb_table = "df-terraform-nonprod-lock-db"
    #profile = "dealerfirestage"
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

output "prod_vpc_id" {
  value = data.terraform_remote_state.ecs_infra.outputs.vpc_id
}

output "prod_public_subnets" {
  value = data.terraform_remote_state.ecs_infra.outputs.public_subnets
}

output "prod_private_subnets" {
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

output "log_group_name" {
  description = "name of ecs cluster log group name"
  value       = data.terraform_remote_state.ecs_infra.outputs.log_group_name
}

output "vpc_cid_block" {
  value = data.terraform_remote_state.ecs_infra.outputs.vpc_cid_block
}

output "lb_dns_name" {
  value = data.terraform_remote_state.ecs_infra.outputs.lb_dns_name
}


resource "aws_security_group" "service-sg" {
  name        = "${var.app_services.name}-sg"
  description = "Allow HTTP and HTTPS traffic inbound"
  vpc_id      = data.terraform_remote_state.ecs_infra.outputs.vpc_id

  tags = merge(
    {
      "Name"        = "${data.terraform_remote_state.ecs_infra.outputs.ecs_infrastructure}-sg-alb",
      "Environment" = var.environment
    },
    data.terraform_remote_state.ecs_infra.outputs.default_tags
  )
}

# tfsec:ignore:AVD-AWS-0107 -- Allow unrestricted ingress on port 80 from a specific security group
resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  description       = "Port 3000 TCP"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks = [data.terraform_remote_state.ecs_infra.outputs.vpc_cid_block]
  security_group_id = aws_security_group.service-sg.id

}
# tfsec:ignore:AVD-AWS-0107 -- Allow unrestricted ingress on port 80 for HTTP web traffic
resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  description       = "Allow egress to all IPs"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.service-sg.id
  cidr_blocks       = ["0.0.0.0/0"]  # Allow all IPv4 addresses
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
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = data.terraform_remote_state.ecs_infra.outputs.log_group_name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = var.app_services.name
      }
    }

    portMappings = [{
      containerPort = var.app_services.ecs_task_container_port
      hostPort      = var.app_services.ecs_task_host_port
    }]
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = var.app_services.name
  cluster         = data.terraform_remote_state.ecs_infra.outputs.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_services.desired_count
  launch_type     = "FARGATE"

  # Define Deployment Configuration for more granular control over the update process
  deployment_maximum_percent        = var.app_services.maximum_percent
  deployment_minimum_healthy_percent = var.app_services.minimum_healthy_percent

  deployment_controller {
    type = "ECS"  # ECS is the default and currently only supported type, which implements Rolling Update
  }

  # Enable the Deployment Circuit Breaker
  deployment_circuit_breaker {
    enable   = true
    rollback = true  # Automatically rollback to the last successful deployment if a failure is detected
  }

  network_configuration {
    subnets         = data.terraform_remote_state.ecs_infra.outputs.private_subnets
    security_groups = [aws_security_group.service-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = var.app_services.name
    container_port   = var.app_services.ecs_task_container_port
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = var.target_group_name
  port     = var.app_services.ecs_task_container_port
  target_type = "ip"
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.ecs_infra.outputs.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    port = var.app_services.ecs_task_container_port
    interval            = 20
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
    http_request_method {
      values = ["GET"]
    }
  }
}

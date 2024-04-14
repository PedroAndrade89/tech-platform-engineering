data "terraform_remote_state" "ecs_infra" {
  backend = "s3"

  config = {
    bucket         = "df-terraform-nonprod"
    key            = "environments/stage/ecs-infra-prod.tf"
    region         = "us-east-1"
    dynamodb_table = "df-terraform-nonprod-lock-db"
  }
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = data.terraform_remote_state.ecs_infra.outputs.ecs_infrastructure
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



resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_services.ecs_task_family
  network_mode             =  var.app_services.network_mode
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      =  var.app_services.ecs_task_cpu
  memory                   =  var.app_services.ecs_task_memory

  container_definitions = jsonencode([{
    name  = var.app_services.name
    image = var.app_services.ecs_task_container_image
    essential = true
    portMappings = [{
      containerPort = var.app_services.ecs_task_container_port
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.public_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "my-app"
    container_port   = 80
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main[0].id

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

resource "aws_lb_listener" "public_listener" {
  load_balancer_arn = aws_lb.public_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

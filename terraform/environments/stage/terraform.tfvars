app_services = {
  ecs_task_family             = "default-family"
  network_mode                = "awsvpc"  // Example: 'bridge', 'host', 'awsvpc'
  ecs_task_cpu                = 256       // Example CPU units
  ecs_task_memory             = 512       // Memory in MB
  name                        = "mews-api-stage"
  ecs_task_container_image    = "your-docker-image:tag"
  desired_count               = 2
  maximum_percent             = 100
  minimum_healthy_percent     = 50
  ecs_task_container_port     = 3000
  ecs_task_host_port          = 3000
  health_check_grace_period_seconds = 30
}
region = "us-east-1"
environment = "stage"
target_group_name = "app-tg-stage"

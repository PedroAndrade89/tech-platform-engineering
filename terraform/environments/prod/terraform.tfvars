app_services = {
  ecs_task_family             = "default-family"
  network_mode                = "awsvpc"  // Example: 'bridge', 'host', 'awsvpc'
  ecs_task_cpu                = 512       // Example CPU units
  ecs_task_memory             = 1024       // Memory in MB
  name                        = "mews-api-prod"
  ecs_task_container_image    = "your-docker-image:tag"
  desired_count               = 3
  ecs_task_container_port     = 3000
  ecs_task_host_port = 3000
}
region = "us-east-1"
environment = "prod"
target_group_name = "app-tg-prod"
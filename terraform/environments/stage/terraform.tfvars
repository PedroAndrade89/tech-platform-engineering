app_services = {
  ecs_task_family             = "default-family"
  network_mode                = "awsvpc"  // Example: 'bridge', 'host', 'awsvpc'
  ecs_task_cpu                = 256       // Example CPU units
  ecs_task_memory             = 512       // Memory in MB
  name                        = "mews-api"
  ecs_task_container_image    = "your-docker-image:tag"
  ecs_task_container_port     = 80
}
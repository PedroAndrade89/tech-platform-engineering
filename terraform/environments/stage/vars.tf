
variable "app_services" {
  description = "Configuration settings for the application services."
  type = object({
    ecs_task_family             = string
    network_mode                = string
    ecs_task_cpu                = number
    ecs_task_memory             = number
    name                        = string
    ecs_task_container_image    = string
    ecs_task_container_port     = number
  })
  default = {
    ecs_task_family             = "default-family"
    network_mode                = "awsvpc"  // Example: 'bridge', 'host', 'awsvpc'
    ecs_task_cpu                = 256       // Example CPU units
    ecs_task_memory             = 512       // Memory in MB
    name                        = "example-app"
    ecs_task_container_image    = "your-docker-image:tag"
    ecs_task_container_port     = 80
  }
}

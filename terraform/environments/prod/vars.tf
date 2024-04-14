

variable "app_services" {
  description = "Map of maps specifying managed node groups"
  type = object({
    name = string
    network_mode = string
    ecs_task_family           = string
    ecs_task_container_image   = string
    ecs_task_container_port       = number
    ecs_task_cpu       = number
    ecs_task_memory = number
    instance_types = list(string)
  })
}
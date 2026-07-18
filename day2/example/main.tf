locals {
  name_prefix   = "${upper(var.environment)}-${join("-", var.tags)}"
  upper_tags    = [for t in var.tags : upper(t)]
  instance_size = var.environment == "prod" ? "large" : "small"
}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "web" {
  count = var.enable_container ? 1 : 0
  name  = var.container_name
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}

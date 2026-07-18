variable "container_name" {
  description = "Name of the docker container"
  type        = string
  default     = "tws-web"
}

variable "external_port" {
  description = "Host port to expose"
  type        = number
  default     = 8080
}

variable "enable_container" {
  description = "Whether to actually create the container"
  type        = bool
  default     = true
}

variable "tags" {
  description = "List of tags"
  type        = list(string)
  default     = ["tws", "terraweek"]
}

variable "labels" {
  description = "Key-value labels"
  type        = map(string)
  default     = { team = "devops" }
}

variable "unique_names" {
  description = "Set of unique names"
  type        = set(string)
  default     = ["web", "api", "db"]
}

variable "container_spec" {
  description = "Structural example using object()"
  type = object({
    name  = string
    ports = number
  })
  default = {
    name  = "tws-web"
    ports = 8080
  }
}

variable "sample_tuple" {
  description = "Structural example using tuple()"
  type        = tuple([string, number, bool])
  default     = ["tws", 2026, true]
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "api_key" {
  description = "Dummy sensitive value for demo purposes"
  type        = string
  default     = "dummy-not-real"
  sensitive   = true
}

variable "env_name" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "instance_count" {
  description = "Number of identical web instances"
  type        = number
  default     = 1
}

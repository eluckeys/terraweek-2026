variable "instance_count" {
  description = "Number of identical web instances (count example)"
  type        = number
  default     = 1
}

variable "named_instances" {
  description = "Named instances with their own instance types (for_each example)"
  type        = map(string)
  default = {
    api = "t3.micro"
    db  = "t3.micro"
  }
}

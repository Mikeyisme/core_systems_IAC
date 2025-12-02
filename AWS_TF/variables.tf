variable "environment" {
  description = "The environment for developer environment"
  type        = string
  default     = "dev"
}

variable "monitoring_enabled" {
  description = "Enable monitoring for EC2 instances"
  type        = bool
  default     = true
}
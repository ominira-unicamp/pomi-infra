variable "name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "lightsail_availability_zone" {
  type = string
}

variable "lightsail_blueprint_id" {
  type = string
}

variable "lightsail_bundle_id" {
  type = string
}

variable "lightsail_snapshot_time" {
  type = string
}

variable "lightsail_ssh_public_key" {
  type = string
}

variable "ssh_allowed_cidrs" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

output "instance_name" {
  value = aws_lightsail_instance.backend.name
}

output "static_ip_address" {
  value = aws_lightsail_static_ip.backend.ip_address
}

output "ssh_user" {
  value = "ubuntu"
}

output "resource_group_name" {
  value = aws_resourcegroups_group.pomi.name
}

output "deployment_target" {
  value = "ubuntu@${aws_lightsail_static_ip.backend.ip_address}"
}

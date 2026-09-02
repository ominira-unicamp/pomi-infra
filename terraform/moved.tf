moved {
  from = aws_lightsail_key_pair.deploy
  to   = module.platform.aws_lightsail_key_pair.deploy
}

moved {
  from = aws_lightsail_instance.backend
  to   = module.platform.aws_lightsail_instance.backend
}

moved {
  from = aws_lightsail_instance_public_ports.backend
  to   = module.platform.aws_lightsail_instance_public_ports.backend
}

moved {
  from = aws_lightsail_static_ip.backend
  to   = module.platform.aws_lightsail_static_ip.backend
}

moved {
  from = aws_lightsail_static_ip_attachment.backend
  to   = module.platform.aws_lightsail_static_ip_attachment.backend
}

moved {
  from = aws_resourcegroups_group.pomi
  to   = module.platform.aws_resourcegroups_group.pomi
}

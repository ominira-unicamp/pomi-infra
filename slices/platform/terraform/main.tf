resource "aws_lightsail_key_pair" "deploy" {
  name       = "${var.name}-deploy"
  public_key = var.lightsail_ssh_public_key
}

resource "aws_lightsail_instance" "backend" {
  name              = var.name
  availability_zone = var.lightsail_availability_zone
  blueprint_id      = var.lightsail_blueprint_id
  bundle_id         = var.lightsail_bundle_id
  key_pair_name     = aws_lightsail_key_pair.deploy.name
  user_data         = file("${path.module}/../templates/bootstrap.sh.tftpl")

  add_on {
    type          = "AutoSnapshot"
    snapshot_time = var.lightsail_snapshot_time
    status        = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [user_data]

    precondition {
      condition     = startswith(var.lightsail_availability_zone, var.aws_region)
      error_message = "lightsail_availability_zone deve pertencer a aws_region."
    }

    precondition {
      condition = (
        (try(trimspace(var.exchange_api_domain_name), "") == "") ==
        (try(trimspace(var.exchange_hosted_zone_name), "") == "")
      )
      error_message = "api_domain_name e hosted_zone_name devem ser informados juntos ou ambos omitidos."
    }
  }

  tags = var.tags
}

resource "aws_lightsail_instance_public_ports" "backend" {
  instance_name = aws_lightsail_instance.backend.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = var.ssh_allowed_cidrs
  }

  port_info {
    protocol          = "tcp"
    from_port         = 80
    to_port           = 80
    cidrs             = ["0.0.0.0/0"]
    cidr_list_aliases = []
  }

  port_info {
    protocol          = "tcp"
    from_port         = 443
    to_port           = 443
    cidrs             = ["0.0.0.0/0"]
    cidr_list_aliases = []
  }
}

resource "aws_lightsail_static_ip" "backend" {
  name = "${var.name}-ip"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lightsail_static_ip_attachment" "backend" {
  static_ip_name = aws_lightsail_static_ip.backend.name
  instance_name  = aws_lightsail_instance.backend.name
}

resource "aws_resourcegroups_group" "pomi" {
  name        = "${var.name}-resources"
  description = "Recursos AWS do POMI Exchange"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Application"
          Values = ["pomi-exchange"]
        }
      ]
    })
  }
}

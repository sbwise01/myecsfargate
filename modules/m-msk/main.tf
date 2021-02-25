resource "random_string" "suffix" {
  length  = 3
  special = false
}

resource "aws_msk_cluster" "main" {
  cluster_name           = local.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_node_instance_type
    ebs_volume_size = var.broker_node_ebs_volume_size
    client_subnets  = var.broker_node_client_subnets
    security_groups = flatten([
      var.broker_node_security_groups,
      aws_security_group.security_group.id
    ])
  }

  enhanced_monitoring = "PER_TOPIC_PER_BROKER"

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  tags = local.tags
}

# DIRTY HACK ALERT
# Unfortunately, the AWS provider just deletes aws_msk_configuration
# from its state when destroying it, and it tries to replace it
# whenever server_properties changes, but AWS won't allow creating a
# new configuration with the same name, so it fails. So instead we
# just generate a new name every time the configuration changes.
locals {
  server_properties_string = join("\n", var.server_properties)
  # TODO this server.properties almost certainly works with more than
  # one version of Kafka.
  kafka_versions = [var.kafka_version]
}

resource "random_id" "msk_config" {
  byte_length = 3
  keepers = {
    # I'm not sure if kafka_versions really forces replacement, but why risk it?
    kafka_versions    = join(",", local.kafka_versions)
    server_properties = local.server_properties_string # Forces replacement
  }
}

resource "aws_msk_configuration" "main" {
  kafka_versions = local.kafka_versions
  # Generate a new name on update
  name              = "${local.cluster_name}-${random_id.msk_config.hex}"
  server_properties = local.server_properties_string
}

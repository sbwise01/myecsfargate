output "arn" {
  description = "Amazon Resource Name (ARN) of the MSK cluster"
  value       = aws_msk_cluster.main.arn
}

output "id" {
  description = "Id of the MSK cluster"
  value       = aws_msk_cluster.main.id
}

output "bootstrap_brokers" {
  description = "Plaintext connection host:port pairs"
  # Make the order deterministic by sorting them
  value = join(",", sort(split(",", aws_msk_cluster.main.bootstrap_brokers)))
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  # Make the order deterministic by sorting them
  value = join(",", sort(split(",", aws_msk_cluster.main.bootstrap_brokers_tls)))
}

output "current_version" {
  description = "Current version of the MSK Cluster used for updates"
  value       = aws_msk_cluster.main.current_version
}

output "zookeeper_connect_string" {
  description = "A comma separated list of one or more hostname:port pairs to use to connect to the Apache Zookeeper cluster."
  value       = aws_msk_cluster.main.zookeeper_connect_string
}

output "msk_security_group_id" {
  description = "Security Group ID for MSK"
  value       = aws_security_group.security_group.id
}

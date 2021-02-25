########################
# MSK module variables #
########################
variable "cluster_name" {
  default     = ""
  description = "Name of the MSK cluster"
  type        = string
}

variable "kafka_version" {
  default     = "2.2.1"
  description = "Specify the desired Kafka software version"
  type        = string
}

variable "number_of_broker_nodes" {
  default     = 3
  description = "The desired total number of broker nodes in the kafka cluster. It must be a multiple of the number of specified client subnets"
  type        = string
}

variable "broker_node_instance_type" {
  default     = "kafka.m5.large"
  description = "Specify the instance type to use for the kafka brokers. e.g. kafka.m5.large."
  type        = string
}

variable "broker_node_ebs_volume_size" {
  default     = 1000
  description = "The size in GiB of the EBS volume for the data drive on each broker node"
  type        = number
}

variable "broker_node_client_subnets" {
  description = "A list of subnets to connect to in client VPC"
  type        = list(string)
}

variable "broker_node_security_groups" {
  description = "A list of the security groups to associate with the elastic network interfaces to control who can communicate with the cluster"
  default     = []
  type        = list(string)
}

variable "server_properties" {
  description = "The server properties for the msk cluster"
  type        = list(string)
}

########################
# SG module variables #
########################
variable "vpc_id" {
  description = "vpc_id for MSK Security Group"
  default     = ""
  type        = string
}

variable "cidr_range" {
  description = "The VPC CIDR range"
  type        = string
}

variable "ecs_ingress_sg_id" {
  description = "The ECS Security Group for Ingress Rule"
  type        = string
}

################
# Tag variable #
################
variable "tags" {
  description = "A map of tags"
  type        = map(string)
}

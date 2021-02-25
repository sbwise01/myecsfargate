locals {
  cluster_name = "${var.cluster_name}-${random_string.suffix.result}"
  tags = merge(var.tags,
    {
      "Name" = format("%s", local.cluster_name)
    },
  )
}
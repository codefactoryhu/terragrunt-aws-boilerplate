terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-iam//modules/iam-role-for-service-accounts-eks?ref=v5.59.0"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../eks"
  mock_outputs = {
    cluster_name = "mock-cluster-name"
  }
}

dependency "irsa" {
  config_path = "${get_original_terragrunt_dir()}/../irsa"
  mock_outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/example-role"
  }
}

inputs = {
  cluster_name                = dependency.eks.outputs.cluster_name
  service_account_role_arn    = dependency.irsa.outputs.iam_role_arn

  addon_name                  = include.locals.ebs_csi_addon_name
  addon_version               = include.locals.ebs_csi_addon_version
  resolve_conflicts_on_create = try(include.locals.ebs_csi_resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(include.locals.ebs_csi_resolve_conflicts_on_update, "OVERWRITE")

  tags = try(include.locals.ebs_csi_tags, {
    Name = "${include.locals.ebs_csi_cluster_name}-${include.locals.ebs_csi_addon_name}-addon"
  })
}

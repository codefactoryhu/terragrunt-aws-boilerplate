terraform {
  source = "../../../../modules//eks-addon"
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

  addon_name                  = include.env.locals.ebs_csi_addon_name
  addon_version               = include.env.locals.ebs_csi_addon_version

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.ebs-csi

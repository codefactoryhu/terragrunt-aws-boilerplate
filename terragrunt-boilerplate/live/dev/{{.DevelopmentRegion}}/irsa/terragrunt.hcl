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
    cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/0000000000000000"
    oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/0000000000000000"
  }
}

inputs = {
  role_name                      = include.env.locals.ebs_irsa_role_name
  attach_ebs_csi_policy          = include.env.locals.ebs_irsa_attach_ebs_csi_policy

  oidc_providers = {
    main = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = include.env.locals.ebs_irsa_namespace_service_accounts
    }
  }

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.irsa

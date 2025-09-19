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
  role_name = include.locals.ebs_irsa_role_name

  oidc_providers = {
    main = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = try(include.locals.ebs_irsa_namespace_service_accounts, [])
    }
  }

  attach_aws_load_balancer_controller_policy = try(include.locals.ebs_irsa_attach_aws_load_balancer_controller_policy, false)
  attach_external_dns_policy                 = try(include.locals.ebs_irsa_attach_external_dns_policy, false)
  attach_external_secrets_policy             = try(include.locals.ebs_irsa_attach_external_secrets_policy, false)
  attach_cert_manager_policy                 = try(include.locals.ebs_irsa_attach_cert_manager_policy, false)
  attach_cluster_autoscaler_policy           = try(include.locals.ebs_irsa_attach_cluster_autoscaler_policy, false)
  attach_ebs_csi_policy                      = try(include.locals.ebs_irsa_attach_ebs_csi_policy, false)
  attach_efs_csi_policy                      = try(include.locals.ebs_irsa_attach_efs_csi_policy, false)
  attach_fsx_lustre_csi_policy               = try(include.locals.ebs_irsa_attach_fsx_lustre_csi_policy, false)
  attach_vpc_cni_policy                      = try(include.locals.ebs_irsa_attach_vpc_cni_policy, false)

  role_policy_arns = try(include.locals.ebs_irsa_role_policy_arns, {})
  allow_self_assume_role = try(include.locals.ebs_irsa_allow_self_assume_role, false)

  tags = try(include.locals.ebs_irsa_tags, {})
}

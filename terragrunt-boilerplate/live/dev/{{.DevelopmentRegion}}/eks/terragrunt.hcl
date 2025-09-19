terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-eks?ref=v21.1.0"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

dependency "vpc" {
  config_path = "${get_original_terragrunt_dir()}/../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    private_subnets = ["subnet-00000000", "subnet-00000001", "subnet-00000002"]
    vpc_cidr_block  = "10.0.0.0/16"
  }
}

dependency "kms" {
  config_path = "${get_original_terragrunt_dir()}/../kms"
  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}

inputs = {
  name               = include.locals.eks_name
  kubernetes_version = include.locals.eks_kubernetes_version

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  cluster_encryption_config = {
    provider_key_arn = dependency.kms.outputs.key_arn
    resources        = ["secrets"]
  }

  endpoint_public_access                   = include.locals.eks_endpoint_public_access
  enable_cluster_creator_admin_permissions = include.locals.eks_enable_cluster_creator_admin_permissions

  access_entries = include.locals.eks_access_entries

  vpc_id                   = dependency.vpc.outputs.vpc_id
  subnet_ids               = dependency.vpc.outputs.private_subnets
  control_plane_subnet_ids = dependency.vpc.outputs.private_subnets

  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = include.locals.eks_instance_types

      min_size     = include.locals.eks_min_size
      max_size     = include.locals.eks_max_size
      desired_size = include.locals.eks_desired_size
    }
  }

  authentication_mode = "API"

  tags = try(include.locals.eks_tags, {
    Name = "${local.project}-${local.env}-eks"
  })
}

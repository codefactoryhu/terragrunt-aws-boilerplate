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

inputs = {
  name               = include.env.locals.eks_name
  kubernetes_version = include.env.locals.eks_kubernetes_version

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

  endpoint_public_access                   = include.env.locals.eks_endpoint_public_access
  enable_cluster_creator_admin_permissions = include.env.locals.eks_enable_cluster_creator_admin_permissions

  access_entries = include.env.locals.eks_access_entries

  vpc_id                   = dependency.vpc.outputs.vpc_id
  subnet_ids               = dependency.vpc.outputs.private_subnets
  control_plane_subnet_ids = dependency.vpc.outputs.private_subnets
  authentication_mode      = include.env.locals.eks_authentication_mode

  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = include.env.locals.eks_instance_types

      min_size     = include.env.locals.eks_min_size
      max_size     = include.env.locals.eks_max_size
      desired_size = include.env.locals.eks_desired_size
    }
  }

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.eks

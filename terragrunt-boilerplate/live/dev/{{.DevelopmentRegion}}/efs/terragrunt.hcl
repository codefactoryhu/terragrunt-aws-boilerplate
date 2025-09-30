terraform {
  source = "git::git@github.com:terraform-aws-modules/efs/aws?ref=v1.8.0"
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
    azs             = ["eu-central-1a", "eu-central-1b"]
    vpc_id          = "vpc-00000000"
    private_subnets = ["subnet-00000000", "subnet-00000001", "subnet-00000002"]
    private_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    vpc_cidr_block  = "10.0.0.0/16"
  }
}

dependency "kms" {
  config_path = "${get_original_terragrunt_dir()}/../kms"
  mock_outputs = {
    kms_key_arn = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }
}

inputs = {
  name           = include.env.locals.efs_description
  creation_token = include.env.locals.efs_creation_token
  encrypted      = include.env.locals.efs_encrypted

  lifecycle_policy = include.env.locals.efs_lifecycle_policy

  attach_policy                      = include.env.locals.efs_attach_policy
  bypass_policy_lockout_safety_check = include.env.locals.efs_bypass_policy_lockout_safety_check

  kms_key_arn    = dependency.kms.kms_key_arn
  mount_targets = {
    for idx, az in dependency.vpc.outputs.azs :
    az => {
      subnet_id = dependency.vpc.outputs.private_subnets[idx]
    }
  }

  security_group_description = "EFS Security group"
  security_group_vpc_id      = dependency.vpc.vpc_id
  security_group_rules = {
    vpc = {
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = dependency.vpc.private_subnets_cidr_blocks
    }
  }

  enable_backup_policy = include.env.locals.efs_enable_backup_policy
  create_replication_configuration = include.env.locals.efs_create_replication_configuration
  replication_configuration_destination = include.env.locals.efs_replication_configuration_destination

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.efs

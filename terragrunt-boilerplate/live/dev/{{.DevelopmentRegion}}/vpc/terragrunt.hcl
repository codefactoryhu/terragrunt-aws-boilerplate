terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-vpc?ref=v6.0.1"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

inputs = {
  name = include.env.locals.vpc_name
  cidr = include.env.locals.vpc_cidr

  azs                         = include.env.locals.vpc_azs
  private_subnets             = include.env.locals.vpc_private_subnets
  public_subnets              = include.env.locals.vpc_public_subnets
  database_subnets            = try(include.env.locals.vpc_database_subnets, [])

  enable_nat_gateway     = try(include.env.locals.vpc_enable_nat_gateway, true)
  single_nat_gateway     = try(include.env.locals.vpc_single_nat_gateway, true)

  enable_flow_log                      = try(include.env.locals.vpc_enable_flow_log, false)
  create_flow_log_cloudwatch_iam_role  = try(include.env.locals.vpc_create_flow_log_cloudwatch_iam_role, false)
  create_flow_log_cloudwatch_log_group = try(include.env.locals.vpc_create_flow_log_cloudwatch_log_group, false)

  public_subnet_tags = merge(
    try(include.env.locals.vpc_public_subnet_tags, {}),
    try(include.env.locals.vpc_cluster_name, null) != null ? {
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${include.env.locals.vpc_cluster_name}" = "owned"
    } : {}
  )

  private_subnet_tags = merge(
    try(include.env.locals.vpc_private_subnet_tags, {}),
    try(include.env.locals.vpc_cluster_name, null) != null ? {
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${include.env.locals.vpc_cluster_name}" = "owned"
    } : {}
  )

  database_subnet_tags = try(include.env.locals.vpc_database_subnet_tags, {
    Type = "Database"
  })

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.vpc

terraform {
  source = "../../../../modules//cross-account-role"
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
  trusted_account_arn = include.env.locals.cross_account_role_trusted_account_arn
  eks_cross_account_role_name = include.env.locals.cross_account_role_name

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.cross-account

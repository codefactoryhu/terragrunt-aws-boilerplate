  terraform {
    source = "git::git@github.com:terraform-aws-modules/kms/aws?ref=v4.1.0"
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
    description  = include.env.locals.kms_description
    key_usage    = include.env.locals.kms_key_usage
    key_administrators = include.env.locals.kms_key_administrators
    aliases = include.env.locals.kms_key_aliases
    key_statements = include.env.locals.kms_key_statements

    tags = include.env.locals.tags
  }

  skip = include.env.locals.skip_module.efs

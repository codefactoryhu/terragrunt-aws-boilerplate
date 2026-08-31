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
  description        = try(include.env.locals.kms_description, "${include.env.locals.project}-${include.env.locals.env} KMS key")
  key_usage          = try(include.env.locals.kms_key_usage, "ENCRYPT_DECRYPT")
  key_administrators = try(include.env.locals.kms_key_administrators, [])
  aliases            = try(include.env.locals.kms_key_aliases, [])
  key_statements     = try(include.env.locals.kms_key_statements, [])

  tags = include.env.locals.tags
}

exclude {
  if      = include.env.locals.skip_module.kms
  actions = ["all"]
}

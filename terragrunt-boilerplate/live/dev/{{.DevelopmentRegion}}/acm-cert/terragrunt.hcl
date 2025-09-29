terraform {
  source = "git::git@github.com:terraform-aws-modules/acm/aws?ref=v6.1.0"
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
  domain_name  = include.env.locals.acm_domain_name
  zone_id      = include.env.locals.acm_zone_id

  validation_method = include.env.locals.acm_validation_method

  subject_alternative_names = include.env.locals.acm_subject_alternative_names

  wait_for_validation = include.env.locals.acm_wait_for_validation

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.acm

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
  domain_name = try(include.env.locals.acm_domain_name, null)
  zone_id     = try(include.env.locals.acm_zone_id, null)

  validation_method         = try(include.env.locals.acm_validation_method, "DNS")
  subject_alternative_names = try(include.env.locals.acm_subject_alternative_names, [])
  wait_for_validation       = try(include.env.locals.acm_wait_for_validation, true)
  tags                      = include.env.locals.tags
}

exclude {
  if      = include.env.locals.skip_module.acm
  actions = ["all"]
}

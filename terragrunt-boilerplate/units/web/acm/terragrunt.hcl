include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-acm?ref=v6.0.0"
}

inputs = {
  domain_name = values.domain_name
  zone_id     = values.hosted_zone_id

  subject_alternative_names = values.subject_alternative_names
  wait_for_validation       = values.wait_for_validation
  validation_method         = "DNS"

  tags = try(values.tags, {})
}
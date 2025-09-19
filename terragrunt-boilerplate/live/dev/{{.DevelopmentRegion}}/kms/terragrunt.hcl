terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-kms?ref=v4.0.0"
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
  description = try(include.env.locals.kms_description, "KMS key for EKS cluster encryption")
  key_usage   = try(include.env.locals.kms_key_usage, "ENCRYPT_DECRYPT")

  key_administrators = try(include.env.locals.kms_key_administrators, [])

  key_statements = try(include.env.locals.kms_key_statements, [
    {
      sid    = "Allow EKS Service"
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["eks.amazonaws.com"]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*"
      ]
      resources = ["*"]
    }
  ])

  aliases = try(include.env.locals.kms_aliases, [])

  deletion_window_in_days = try(include.env.locals.kms_deletion_window_in_days, 7)

  tags = include.env.locals.tags
}

skip = include.env.locals.skip_module.kms

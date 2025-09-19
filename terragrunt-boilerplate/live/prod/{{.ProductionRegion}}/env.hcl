locals {
  env         = "prod"
  region      = "{{.ProductionRegion}}"
  project     = "{{.ProjectName}}"
  account_id  = "{{.ProductionAccountId}}"

  organization_id           = "{{.OrganizationId}}"
  organization_root_id      = "{{.OrganizationRootId}}"

  project_version = "{{.ProjectVersion}}"
  iam_role        = "arn:aws:iam::${local.account_id}:role/terragrunt-execution-role"

  # Skip modules
  skip_module = {

  }

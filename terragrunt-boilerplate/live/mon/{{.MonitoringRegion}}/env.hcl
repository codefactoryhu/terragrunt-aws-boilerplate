locals {
  env         = "mon"
  region      = "{{.MonitoringRegion}}"
  project     = "{{.ProjectName}}"
  account_id  = "{{.MonitoringAccountId}}"

  organization_id           = "{{.OrganizationId}}"
  organization_root_id      = "{{.OrganizationRootId}}"

  project_version = "{{.ProjectVersion}}"
  iam_role        = "arn:aws:iam::${local.account_id}:role/terragrunt-execution-role"

  # Skip modules
  skip_module = {

  }

  tags = {
    Name            = "${local.env}-${local.project}"
    Environment     = "${local.env}"
    Project-version = "${local.project_version}"
  }
}

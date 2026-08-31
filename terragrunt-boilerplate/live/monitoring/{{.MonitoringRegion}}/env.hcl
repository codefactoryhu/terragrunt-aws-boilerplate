locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  project             = local.project_vars.locals.project
  project_version     = local.project_vars.locals.project_version
  default_region      = local.project_vars.locals.default_region
  notification_emails = local.project_vars.locals.notification_emails

  eks_sso_access_role_name = run_cmd("mise", "run", "get-sso-role")
  execution_role           = local.project_vars.locals.execution_role

  account_id = local.account_vars.locals.account_id
  account    = local.account_vars.locals.account
  env        = local.account_vars.locals.account

  region = local.default_region

  # Skip modules
  skip_module = {

  }

  tags = {
    Name            = "${local.env}-${local.project}"
    Environment     = "${local.env}"
    Project         = "${local.project}"
    Project-version = "${local.project_version}"
  }
}

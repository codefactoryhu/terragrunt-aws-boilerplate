locals {
  project                = "{{ .ProjectName }}"
  project_version        = "{{ .ProjectVersion }}"
  default_region         = "{{ .DevelopmentRegion }}"
  development_account_id = "{{ .DevelopmentAccountId }}"
  notification_emails    = ["{{ .EmailDomain }}"]
  execution_role         = "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"


  remote_origin_url = run_cmd("mise", "run", "get-git-config", "--url")
  repository        = run_cmd("mise", "run", "get-git-config", "--owner-and-repo")
}

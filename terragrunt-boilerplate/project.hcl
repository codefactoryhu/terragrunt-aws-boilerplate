locals {
  project                = "{{ .ProjectName }}"
  project_version        = "{{ .ProjectVersion }}"
  default_region         = "{{ .DevelopmentRegion }}"
  development_account_id = "{{ .DevelopmentAccountId }}"
  notification_emails    = ["{{ .EmailDomain }}"]

  # remote_origin_url dynamic     = run_cmd("git", "config", "--get", "remote.origin.url")
  # repository dynamic            = trimprefix(trimsuffix(local.remote_origin_url, ".git"), "https://github.com/")
  remote_origin_url = "https://github.com/<OWNER>/<REPOSITORY>.git"
  repository        = "<OWNER>/<REPOSITORY>"

  # caller_identity          = jsondecode(run_cmd("aws", "sts", "get-caller-identity", "--output", "json"))
  # eks_sso_access_role_name = split("/", local.caller_identity.Arn)[1]
  eks_sso_access_role_name = "<ROLE_NAME>"
}

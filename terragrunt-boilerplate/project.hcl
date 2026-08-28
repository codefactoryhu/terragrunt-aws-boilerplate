locals {
  project                = "{{ .ProjectName }}"
  project_version        = "{{ .ProjectVersion }}"
  default_region         = "{{ .DevelopmentRegion }}"
  remote_origin_url      = run_cmd("git", "config", "--get", "remote.origin.url")
  repository             = trimprefix(trimsuffix(local.remote_origin_url, ".git"), "https://github.com/")
  development_account_id = "{{ .DevelopmentAccountId }}"
  notification_emails    = ["{{ .EmailDomain }}"]
}

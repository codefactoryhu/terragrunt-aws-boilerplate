locals {
  project                = "{{ .ProjectName }}"
  project_version        = "{{ .ProjectVersion }}"
  default_region         = "{{ .DevelopmentRegion }}"
  development_account_id = "{{ .DevelopmentAccountId }}"
  notification_emails    = ["{{ .EmailDomain }}"]
  # remote_origin_url dynamic     = run_cmd("git", "config", "--get", "remote.origin.url")
  # repository dynamic             = trimprefix(trimsuffix(local.remote_origin_url, ".git"), "https://github.com/")
  remote_origin_url = "https://github.com/<OWNER>/<REPOSITORY>.git"
  repository        = "<OWNER>/<REPOSITORY>"
}

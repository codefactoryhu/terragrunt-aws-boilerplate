locals {
  project         = "{{.ProjectName}}"
  project_version = "{{.ProjectVersion}}"

  organization_id      = "{{.OrganizationId}}"
  organization_root_id = "{{.OrganizationRootId}}"

  management_account_id  = "{{.ManagementAccountId}}"
  monitoring_account_id  = "{{.MonitoringAccountId}}"
  production_account_id  = "{{.ProductionAccountId}}"
  development_account_id = "{{.DevelopmentAccountId}}"

  management_account_email  = "{{.ManagementEmail}}"
  monitoring_account_email  = "{{.MonitoringEmail}}"
  production_account_email  = "{{.ProductionEmail}}"
  development_account_email = "{{.DevelopmentEmail}}"
}
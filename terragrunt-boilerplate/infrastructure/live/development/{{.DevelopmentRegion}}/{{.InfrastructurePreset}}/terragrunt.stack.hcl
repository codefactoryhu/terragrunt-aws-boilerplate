locals {
  env             = "development"
  region          = "{{.DevelopmentRegion}}"
  project         = "{{.ProjectName}}"
  project_version = "{{.ProjectVersion}}"

  development_account_id    = "{{.DevelopmentAccountId}}"
  development_account_email = "{{.EmailDomain}}"
  organization_id           = "{{.OrganizationId}}"
  organization_root_id      = "{{.OrganizationRootId}}"
  {{ if eq .InfrastructurePreset "web" }}
  domains = {
    primary = "example.com"
    www     = "www.example.com"
  }
  {{ end }}
}
{{ if eq .InfrastructurePreset "vpc" }}
unit "vpc" {
  source = "../../../../../units/vpc"
  path   = "vpc"

  values = {
    name = "${local.project}-${local.env}-vpc"
    cidr = "10.0.0.0/16"

    azs             = ["${local.region}a", "${local.region}b"]
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false

    enable_dns_hostnames = true
    enable_dns_support   = true

    enable_flow_log                      = false
    create_flow_log_cloudwatch_iam_role  = false
    create_flow_log_cloudwatch_log_group = false

    tags = {
      Name      = "${local.project}-${local.env}-vpc"
      ManagedBy = "Terragrunt"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "web" }}
unit "acm" {
  source = "../../../../../units/web/acm"
  path   = "acm"

  values = {
    hosted_zone_id                  = "<HOSTED_ZONE_ID>"
    domain_name                     = local.domains.primary
    subject_alternative_names       = [local.domains.www]
    wait_for_validation             = true

    tags = {
      Name = "${local.project}-ssl"
    }
  }
}

unit "webacl" {
  source = "../../../../../units/web/webacl"
  path   = "webacl"

  values = {
    name        = "${local.project}-waf"
    name_prefix = "${local.project}-waf"
    scope       = "CLOUDFRONT"

    tags = {
      Name = "${local.project}-waf"
    }
  }
}

unit "s3" {
  source = "../../../../../units/web/s3"
  path   = "s3"

  values = {
    bucket_name = "${local.project}-site-<UNIQUE_SUFFIX>"

    website = {
      index_document = "index.html"
      error_document = "error.html"
    }

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
    
    versioning = {
      enabled = true
    }

    lifecycle_rule = [
      {
        id      = "delete_old_versions"
        enabled = true
        noncurrent_version_expiration = {
          days = 30
        }
      }
    ]

    tags = {
      Name = "${local.project}-site-<UNIQUE_SUFFIX>"
    }
  }
}

unit "cloudfront" {
  source = "../../../../../units/web/cloudfront"
  path   = "cloudfront"

  values = {
    s3_path                = "../s3"
    acm_path               = "../acm"
    webacl_path            = "../webacl"

    aliases = ["${local.domains.www}", "${local.domains.primary}"]

    tags = {
      Name = "${local.project}-cloudfront"
    }
  }
}

unit "route53_records" {
  source = "../../../../../units/web/route53"
  path   = "route53-records"

  values = {
    cloudfront_path = "../cloudfront"
    
    primary_domain = "${local.domains.primary}"

    domain_names = ["${local.domains.primary}", "${local.domains.www}"]
    enable_ipv6  = true

    additional_records = [
      {
        name    = "mail"
        type    = "MX"
        ttl     = 300
        records = ["10 mail.${local.domains.primary}"]
      }
    ]

    tags = {
      Name = "${local.project}-dns-records"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "eks-auto" }}
unit "vpc" {
  source = "../../../../../units/eks-auto/vpc"
  path   = "vpc"

  values = {
    name = "${local.project}-${local.env}-vpc"
    cidr = "10.0.0.0/16"

    azs             = ["${local.region}a", "${local.region}b"]
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false

    enable_dns_hostnames = true
    enable_dns_support   = true

    enable_flow_log                      = false
    create_flow_log_cloudwatch_iam_role  = false
    create_flow_log_cloudwatch_log_group = false


    cluster_name = "${local.env}-eks"


    tags = {
      Name      = "${local.project}-${local.env}-vpc"
      ManagedBy = "Terragrunt"
    }
  }
}

unit "kms" {
  source = "../../../../../units/eks-auto/kms"
  path   = "kms"

  values = {
    description = "KMS key for EKS cluster encryption"
    aliases     = ["alias/eks-cluster-encryption-terragrunt"]

    key_administrators = [
      "arn:aws:iam::${local.development_account_id}:root",
      "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = {
      Name    = "eks-cluster-kms-key"
      Purpose = "EKS-Encryption"
    }
  }
}

unit "cross-account-role" {
  source = "../../../../../units/cross-account-role"
  path   = "cross-account-role"

  values = {
    trusted_account_arn         = "arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/eu-central-1/<ROLE_NAME>"
    eks_cross_account_role_name = "eks-cross-account-access"
  }
}

unit "eks" {
  source = "../../../../../units/eks-auto/eks"
  path   = "eks"

  values = {
    vpc_path = "../vpc"
    kms_path = "../kms"

    name               = "${local.env}-eks"
    kubernetes_version = "1.33"

    endpoint_public_access                   = true
    enable_cluster_creator_admin_permissions = true

    access_entries = {
      test = {
        principal_arn = "arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/<AWS_REGION>/<ROLE_NAME>"

        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              namespace = []
              type      = "cluster"
            }
          }
        }
      },
      cross-accoount = {
        principal_arn = "arn:aws:iam::<ACCOUNT_ID>:role/eks-cross-account-access"

        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              namespace = []
              type      = "cluster"
            }
          }
        }
      }
    }


    tags = {
      Name    = "${local.env}-eks"
      EKSMode = "Managed"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "eks-managed" }}
unit "vpc" {
  source = "../../../../../units/eks-managed/vpc"
  path   = "vpc"

  values = {
    name = "${local.project}-${local.env}-vpc"
    cidr = "10.0.0.0/16"

    azs             = ["${local.region}a", "${local.region}b"]
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false

    enable_dns_hostnames = true
    enable_dns_support   = true

    enable_flow_log                      = false
    create_flow_log_cloudwatch_iam_role  = false
    create_flow_log_cloudwatch_log_group = false


    cluster_name = "${local.env}-eks"


    tags = {
      Name      = "${local.project}-${local.env}-vpc"
      ManagedBy = "Terragrunt"
    }
  }
}

unit "kms" {
  source = "../../../../../units/eks-managed/kms"
  path   = "kms"

  values = {
    description = "KMS key for EKS cluster encryption"
    aliases     = ["alias/eks-cluster-encryption-terragrunt"]

    key_administrators = [
      "arn:aws:iam::${local.development_account_id}:root",
      "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = {
      Name    = "eks-cluster-kms-key"
      Purpose = "EKS-Encryption"
    }
  }
}

unit "cross-account-role" {
  source = "../../../../../units/eks-managed/cross-account-role"
  path   = "cross-account-role"

  values = {
    trusted_account_arn         = "arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/eu-central-1/<ROLE_NAME>"
    eks_cross_account_role_name = "eks-cross-account-access"
  }
}

unit "eks" {
  source = "../../../../../units/eks-managed/eks"
  path   = "eks"

  values = {
    vpc_path = "../vpc"
    kms_path = "../kms"

    name               = "${local.env}-eks"
    kubernetes_version = "1.33"

    endpoint_public_access                   = true
    enable_cluster_creator_admin_permissions = true

    access_entries = {
      test = {
        principal_arn = "arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/<AWS_REGION>/<ROLE_NAME>"

        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              namespace = []
              type      = "cluster"
            }
          }
        }
      },
      cross-accoount = {
        principal_arn = "arn:aws:iam::<ACCOUNT_ID>:role/eks-cross-account-access"

        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              namespace = []
              type      = "cluster"
            }
          }
        }
      }
    }

    instance_types = ["t3.medium"]
    min_size       = 1
    max_size       = 3
    desired_size   = 2

    tags = {
      Name    = "${local.env}-eks"
      EKSMode = "Managed"
    }
  }
}

unit "ebs-irsa" {
  source = "../../../../../units/eks-managed/iam-role"
  path   = "ebs-irsa"

  values = {
    eks_path = "../eks"

    role_name                  = "${local.project}-${local.env}-ebs-irsa"
    namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]

    attach_ebs_csi_policy = true

    tags = {
      Name = "${local.project}-${local.env}-irsa-role"
    }
  }
}

unit "ebs-csi-addon" {
  source = "../../../../../units/eks-managed/eks-addon"
  path   = "ebs-csi-addon"

  values = {
    eks_path = "../eks"
    irsa_path = "../ebs-irsa"

    addon_name    = "aws-ebs-csi-driver"
    addon_version = "v1.48.0-eksbuild.1"

    tags = {
      Name = "${local.project}-${local.env}-ebs-csi-addon"
    }
  }
}

unit "aws-lbc" {
  source = "../../../../../units/eks-managed/aws-lbc"
  path   = "aws-lbc"

  values = {
    enable_aws_load_balancer_controller = true

    eks_path = "../eks"
    vpc_path = "../vpc"

    tags = {
      Name = "${local.project}-${local.env}-aws-lbc"
    }
  }
}
{{ end }}

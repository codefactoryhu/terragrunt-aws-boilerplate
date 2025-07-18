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
  {{ if eq .InfrastructurePreset "serverless" }}
  allow_origins = ["https://exakmpledomain.com", "https://app.exakmpledomain.com"]
  {{ end }}
  tags = {
    Project     = local.project
    Environment = local.env
    Maintainer   = "Terragrunt"
  }
}
{{ if or (eq .InfrastructurePreset "vpc") (eq .InfrastructurePreset "eks-auto") (eq .InfrastructurePreset "eks-managed") (eq .InfrastructurePreset "serverless") }}
unit "vpc" {
  source = "../../../../../units/vpc"
  path   = "vpc"

  values = {
    name = "${local.project}-${local.env}-vpc"
    cidr = "10.0.0.0/16"

    azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
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

    {{ if or (eq .InfrastructurePreset "eks-auto") (eq .InfrastructurePreset "eks-managed") }}
    cluster_name = "${local.project}-${local.env}-cluster"
    {{ end }}
    {{ if eq .InfrastructurePreset "serverless" }}
    database_subnets                   = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
    create_database_subnet_group       = true
    create_database_subnet_route_table = true

    enable_s3_endpoint       = true
    enable_dynamodb_endpoint = true

    public_subnet_tags = {
      Type = "Public"
    }
    private_subnet_tags = {
      Type = "Private"
    }
    database_subnet_tags = {
      Type = "Database"
    }
    {{ end }}
    tags = {
      Name        = "${local.project}-${local.env}-vpc"
      Environment = "development"
      Project     = "${local.project}"
      ManagedBy   = "Terragrunt"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "web" }}
unit "route53_zones" {
  source = "../../../../../units/route53-zones"
  path   = "route53-zones"

  values = {
    zones = {
      "${local.domains.primary}" = {
        comment = "Hosted zone for ${local.domains.primary}"
        tags = {
          Name = local.domains.primary
        }
      }
    }

    tags = {
      Name = "${local.project}-dns-zones"
    }
  }
}

unit "acm" {
  source = "../../../../../units/acm"
  path   = "acm"

  values = {
    route53_path              = "../route53-zones"
    domain_name               = local.domains.primary
    subject_alternative_names = [local.domains.www]
    wait_for_validation       = true

    tags = {
      Name = "${local.project}-ssl"
    }
  }
}

unit "webacl" {
  source = "../../../../../units/webacl"
  path   = "webacl"

  values = {
    name  = "${local.project}-waf"
    name_prefix = "cloudfront"
    scope = "CLOUDFRONT"

    rules = [
      {
        name            = "AWSManagedRulesCommonRuleSet"
        priority        = 1
        override_action = "none"
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "CommonRuleSetMetric"
          sampled_requests_enabled   = true
        }
        managed_rule_group_statement = {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }
    ]

    rate_based_rules = [
      {
        name     = "RateLimitRule"
        priority = 100
        action   = "block"
        limit    = 2000
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "RateLimitRule"
          sampled_requests_enabled   = true
        }
      }
    ]

    tags = {
      Name = "${local.project}-waf"
    }
  }
}

unit "s3" {
  source = "../../../../../units/s3"
  path   = "s3"

  values = {
    bucket_name = "${local.project}-static-site-codefactory"

    website = {
      index_document = "index.html"
      error_document = "error.html"
    }

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true

    attach_policy = true
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "AllowCloudFrontServicePrincipal"
          Effect    = "Allow"
          Principal = {
            Service = "cloudfront.amazonaws.com"
          }
          Action   = "s3:GetObject"
          Resource = "arn:aws:s3:::${local.project}-static-site-codefactory/*"
          Condition = {
            StringEquals = {
              "AWS:SourceArn" = "arn:aws:cloudfront::${local.development_account_id}:distribution/*"
            }
          }
        }
      ]
    })

    versioning = {
      enabled = true
    }

    server_side_encryption_configuration = {
      rule = {
        apply_server_side_encryption_by_default = {
          sse_algorithm = "AES256"
        }
        bucket_key_enabled = true
      }
    }

    cors_rule = [
      {
        allowed_headers = ["*"]
        allowed_methods = ["GET", "HEAD"]
        allowed_origins = ["*"]
        expose_headers  = ["ETag"]
        max_age_seconds = 3000
      }
    ]

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
      Name = "${local.project}-static-site"
    }
  }
}

unit "cloudfront" {
  source = "../../../../../units/cloudfront"
  path   = "cloudfront"

  values = {
    s3_path                = "../s3"
    webacl_path            = "../webacl"
    acm_path               = "../acm"
    enable_waf             = true
    use_custom_certificate = true

    aliases = ["${local.domains.www}", "${local.domains.primary}"]
    comment = "CloudFront distribution for my web project"

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400


    custom_error_response = [
      {
        error_code         = 404
        response_code      = 404
        response_page_path = "/error.html"
      },
      {
        error_code         = 403
        response_code      = 404
        response_page_path = "/error.html"
      }
    ]

    tags = {
      Name = "${local.project}-cloudfront"
    }
  }
}

unit "route53_records" {
  source = "../../../../../units/route53"
  path   = "route53-records"

  values = {
    cloudfront_path    = "../cloudfront"
    route53_zones_path = "../route53-zones"
    
    primary_domain = local.domains.primary

    domain_names = ["${local.domains.primary}", "${local.domains.www}"]
    enable_ipv6  = true

    additional_records = [
      {
        name    = local.domains.primary
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
unit "kms" {
  source = "../../../../../units/kms"
  path   = "kms"

  values = {
    description = "KMS key for EKS cluster encryption"
    aliases     = ["alias/eks-cluster-encryption"]

    key_administrators = [
      "arn:aws:iam::${local.development_account_id}:root",
      "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = {
      Name        = "eks-cluster-kms-key"
      Environment = "development"
      Purpose     = "EKS-Encryption"
    }
  }
}

unit "eks" {
  source = "../../../../../units/eks"
  path   = "eks"

  values = {
    vpc_path = "../vpc"
    kms_path = "../kms"

    cluster_name    = "${local.project}-cluster"
    cluster_version = "1.31"

    enable_auto_mode              = true
    bootstrap_self_managed_addons = true
    
    node_pools = ["general-purpose"]

    cluster_addons = {
      coredns = {
        preserve    = true
        most_recent = true
      }
      eks-pod-identity-agent = {
        preserve    = true
        most_recent = true
      }
      kube-proxy = {
        preserve    = true
        most_recent = true
      }
      vpc-cni = {
        preserve    = true
        most_recent = true
      }
    }

    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = true
    cluster_endpoint_public_access_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

    authentication_mode = "API_AND_CONFIG_MAP"

    access_entries = {
      admin = {
        principal_arn     = "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
        kubernetes_groups = ["system:masters"]
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }

    enable_irsa = true

    enable_kms_encryption = true

    cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    cloudwatch_log_group_retention_in_days = 30
    create_cloudwatch_log_group            = true

    cluster_security_group_additional_rules = {
      ingress_nodes_443 = {
        description                = "Node groups to cluster API"
        protocol                   = "tcp"
        from_port                  = 443
        to_port                    = 443
        type                       = "ingress"
        source_node_security_group = true
      }
    }
    
    node_security_group_additional_rules = {
      ingress_self_all = {
        description = "Node to node all ports/protocols"
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        type        = "ingress"
        self        = true
      }
      
      egress_all = {
        description      = "Node all egress"
        protocol         = "-1"
        from_port        = 0
        to_port          = 0
        type             = "egress"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
      }
    }

    tags = {
      Name        = "${local.project}-cluster"
      Environment = "development"
      ManagedBy   = "Terragrunt"
      EKSMode     = "Auto"
    }
  }
}

unit "additional_iam_roles" {
  source = "../../../../../units/iam-role"
  path   = "additional-iam-roles"

  values = {
    eks_path = "../eks"

    role_name = "external-dns-role"

    namespace_service_accounts = ["kube-system:external-dns"]

    attach_external_dns_policy = true

    role_policy_arns = {}

    tags = {
      Name        = "external-dns-role"
      Environment = "development"
      Purpose     = "External-DNS"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "eks-managed" }}
unit "kms" {
  source = "../../../../../units/kms"
  path   = "kms"

  values = {
    description = "KMS key for EKS cluster encryption"
    aliases     = ["alias/eks-cluster-encryption"]

    key_administrators = [
      "arn:aws:iam::${local.development_account_id}:root",
      "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = {
      Name        = "eks-cluster-kms-key"
      Environment = "development"
      Purpose     = "EKS-Encryption"
    }
  }
}

unit "eks" {
  source = "../../../../../units/eks"
  path   = "eks"

  values = {
    vpc_path = "../vpc"
    kms_path = "../kms"

    cluster_name    = "${local.project}-cluster"
    cluster_version = "1.31"

    enable_auto_mode              = false
    bootstrap_self_managed_addons = true

    eks_managed_node_groups = {
      default = {
        min_size       = 1
        max_size       = 3
        desired_size   = 2
        instance_types = ["t3.medium"]
        ami_type       = "AL2_x86_64"
        capacity_type  = "ON_DEMAND"

        labels = {
          Environment = "development"
          NodeGroup   = "default"
        }

        taints = []
        
        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = 20
              volume_type           = "gp3"
              encrypted             = true
              delete_on_termination = true
            }
          }
        }

        update_config = {
          max_unavailable_percentage = 25
        }

        metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags      = "disabled"
        }
      }
    }

    cluster_addons = {
      coredns = {
        version = "v1.11.1-eksbuild.4"
      }
      kube-proxy = {
        version = "v1.31.0-eksbuild.3"
      }
      vpc-cni = {
        version = "v1.18.1-eksbuild.3"
      }
    }

    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = true
    cluster_endpoint_public_access_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

    authentication_mode = "API_AND_CONFIG_MAP"

    access_entries = {
      admin = {
        principal_arn     = "arn:aws:iam::${local.development_account_id}:role/terragrunt-execution-role"
        kubernetes_groups = ["system:masters"]
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }

    enable_irsa = true

    enable_kms_encryption = true

    cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    cloudwatch_log_group_retention_in_days = 30
    create_cloudwatch_log_group            = true

    cluster_security_group_additional_rules = {
      ingress_nodes_443 = {
        description                = "Node groups to cluster API"
        protocol                   = "tcp"
        from_port                  = 443
        to_port                    = 443
        type                       = "ingress"
        source_node_security_group = true
      }
    }
    
    node_security_group_additional_rules = {
      ingress_self_all = {
        description = "Node to node all ports/protocols"
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        type        = "ingress"
        self        = true
      }
      
      egress_all = {
        description      = "Node all egress"
        protocol         = "-1"
        from_port        = 0
        to_port          = 0
        type             = "egress"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
      }
    }

    tags = {
      Name        = "${local.project}-cluster"
      Environment = "development"
      ManagedBy   = "Terragrunt"
      EKSMode     = "Managed"
    }
  }
}

unit "ebs_csi_driver" {
  source = "../../../../../units/ebs-csi-driver"
  path   = "ebs-csi-driver"

  values = {
    eks_path = "../eks"
    kms_path = "../kms"

    role_name                  = "ebs-csi-driver-role"
    namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]

    enable_kms_encryption = true

    tags = {
      Name        = "ebs-csi-driver-role"
      Environment = "development"
      Purpose     = "EBS-CSI-Driver"
    }
  }
}

unit "aws_load_balancer_controller" {
  source = "../../../../../units/aws-lbc"
  path   = "aws-load-balancer-controller"

  values = {
    eks_path = "../eks"

    helm_chart_name         = "aws-load-balancer-controller"
    helm_chart_release_name = "aws-load-balancer-controller"
    helm_chart_repo         = "https://aws.github.io/eks-charts"
    helm_chart_version      = "1.8.4"

    namespace            = "kube-system"
    service_account_name = "aws-load-balancer-controller"

    irsa_role_name_prefix = "aws-load-balancer-controller"

    # need vpc id?
    helm_chart_values = [
      <<-EOT
      clusterName: ${local.project}-cluster
      serviceAccount:
        create: true
        name: aws-load-balancer-controller
      region: ${local.region}
      EOT
    ]

    tags = {
      Name        = "aws-load-balancer-controller"
      Environment = "development"
      Purpose     = "Load-Balancer-Controller"
    }
  }
}

unit "additional_iam_roles" {
  source = "../../../../../units/iam-role"
  path   = "additional-iam-roles"

  values = {
    eks_path = "../eks"

    role_name = "external-dns-role"

    namespace_service_accounts = ["kube-system:external-dns"]

    attach_external_dns_policy = true

    role_policy_arns = {}

    tags = {
      Name        = "external-dns-role"
      Environment = "development"
      Purpose     = "External-DNS"
    }
  }
}
{{ end }}
{{ if eq .InfrastructurePreset "serverless" }}
unit "rds_security_group" {
  source = "../../../../../units/security-group"
  path   = "rds-security-group"

  values = {
    vpc_path = "../vpc"
    
    name        = "${local.project}-${local.env}-rds-sg"
    description = "Security group for RDS database"
    
    ingress_with_cidr_blocks = [
      {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = "10.0.0.0/16"
        description = "MySQL access from VPC"
      }
    ]
    
    egress_with_cidr_blocks = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = "0.0.0.0/0"
        description = "All outbound traffic"
      }
    ]
    
    tags = {
      Name        = "${local.project}-${local.env}-rds-sg"
      Environment = "development"
      Purpose     = "RDS-Database-Access"
    }
  }
}

unit "rds" {
  source = "../../../../../units/rds-lambda"
  path   = "rds"

  values = {
    vpc_path            = "../vpc"
    security_group_path = "../rds-security-group"
    kms_path            = "../kms-serverless"

    identifier = "${local.project}-${local.env}-db"

    engine               = "mysql"
    engine_version       = "8.0.39"
    major_engine_version = "8.0"
    family               = "mysql8.0"
    instance_class       = "db.t3.micro"

    allocated_storage     = 20
    max_allocated_storage = 100
    storage_type          = "gp3"
    storage_encrypted     = true

    db_name  = "appdb"
    username = "dbadmin"

    manage_master_user_password   = true
    master_user_secret_kms_key_id = "alias/${local.project}/${local.env}/serverless"

    create_db_parameter_group = true
    create_db_option_group    = false

    backup_retention_period = 7
    backup_window           = "03:00-04:00"
    maintenance_window      = "sun:04:00-sun:05:00"

    monitoring_interval    = 60
    create_monitoring_role = true

    performance_insights_enabled          = true
    performance_insights_retention_period = 7

    multi_az = true

    deletion_protection = true
    skip_final_snapshot = false
    final_snapshot_identifier = "${local.project}-${local.env}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

    parameters = [
      {
        name  = "innodb_buffer_pool_size"
        value = "{DBInstanceClassMemory*3/4}"
      },
      {
        name  = "max_connections"
        value = "1000"
      }
    ]

    tags = {
      Name        = "${local.project}-${local.env}-database"
      Environment = "development"
      Purpose     = "Application-Database"
    }
  }
}

unit "lambda_security_group" {
  source = "../../../../../units/security-group"
  path   = "lambda-security-group"

  values = {
    vpc_path = "../vpc"
    
    name        = "${local.project}-${local.env}-lambda-sg"
    description = "Security group for Lambda function"
    
    ingress_with_cidr_blocks = []
    
    egress_with_cidr_blocks = [
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = "0.0.0.0/0"
        description = "HTTPS to internet"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = "0.0.0.0/0"
        description = "HTTP to internet"
      },
      {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = "10.0.0.0/16"
        description = "MySQL to RDS"
      },
      {
        from_port   = 53
        to_port     = 53
        protocol    = "udp"
        cidr_blocks = "0.0.0.0/0"
        description = "DNS"
      }
    ]
    
    tags = {
      Name        = "${local.project}-${local.env}-lambda-sg"
      Environment = "development"
      Purpose     = "Lambda-Function-Access"
    }
  }
}

unit "lambda" {
  source = "../../../../../units/lambda"
  path   = "lambda"

  values = {
    vpc_path            = "../vpc"
    rds_path            = "../rds"
    security_group_path = "../lambda-security-group"
    dlq_path            = "../lambda-dlq"
    kms_path            = "../kms-serverless"

    function_name = "${local.project}-app"
    description   = "Main serverless application function"
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.11"
    timeout       = 15 
    memory_size   = 256

    # Option 1: Local zip file
    local_existing_package = "${get_parent_terragrunt_dir()}/../../src/lambda_function.zip"
    create_package = false

    # Option 2: S3 source code (uncomment to use)
    # s3_existing_package = {
    #   bucket = "my-lambda-deployments"
    #   key    = "${local.project}-${local.env}/lambda.zip"
    # }

    environment_variables = {
      LOG_LEVEL          = "INFO"
      ENVIRONMENT        = "development"
      APP_NAME           = "${local.project}-app"
      DB_CONNECTION_POOL = "10"
    }

    reserved_concurrent_executions = 100

    layers = []

    cloudwatch_logs_retention_in_days = 14

    tracing_config_mode = "Active"

    tags = {
      Name        = "${local.project}-app"
      Environment = "development"
      Purpose     = "Main-Application-Function"
    }
  }
}

unit "api_gateway" {
  source = "../../../../../units/api-gateway"
  path   = "api-gateway"

  values = {
    lambda_path = "../lambda"

    name        = "${local.project}-api"
    description = "HTTP API for ${local.project} application"

    cors_configuration = {
      allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
      allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      allow_origins     = local.allowed_origins
      expose_headers    = ["date", "keep-alive"]
      max_age           = 86400
      allow_credentials = false
    }

    # Domain configuration
    # domain_name                 = "api.yourdomain.com"
    # domain_name_certificate_arn = "arn:aws:acm:us-east-1:${local.development_account_id}:certificate/12345678-1234-1234-1234-${local.development_account_id}"
    # create_api_domain_name      = true

    default_route_settings = {
      detailed_metrics_enabled = true
      throttling_burst_limit   = 1000
      throttling_rate_limit    = 500
    }

    access_log_destination_arn = "arn:aws:logs:${local.region}:${local.development_account_id}:log-group:/aws/apigateway/${local.project}-${local.env}-api"
    access_log_format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      error            = "$context.error.message"
      integrationError = "$context.integration.error"
    })

    tags = {
      Name        = "${local.project}-api"
      Environment = "development"
      Purpose     = "Application-API"
    }
  }
}


unit "kms_serverless" {
  source = "../../../../../units/kms-serverless"
  path   = "kms-serverless"

  values = {
    description = "KMS key for ${local.project} serverless application encryption"
    account_id  = local.development_account_id
    
    aliases = ["${local.project}/${local.env}/serverless"]
    
    enable_key_rotation = true
    
    tags = {
      Name        = "${local.project}-${local.env}-serverless-kms"
      Environment = local.env
      Purpose     = "Serverless-Encryption"
    }
  }
}

unit "lambda_dlq" {
  source = "../../../../../units/sqs-dlq"
  path   = "lambda-dlq"

  values = {
    name = "${local.project}-${local.env}-lambda-dlq"
    
    message_retention_seconds = 1209600  # 14 days
    visibility_timeout_seconds = 300     # 5 minutes
    
    kms_master_key_id = "alias/${local.project}/${local.env}/serverless"
    
    create_queue_policy = true
    queue_policy_statements = {
      lambda_access = {
        sid    = "AllowLambdaService"
        effect = "Allow"
        principals = [
          {
            type        = "Service"
            identifiers = ["lambda.amazonaws.com"]
          }
        ]
        actions = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        resources = ["*"]
      }
    }
    
    tags = {
      Name        = "${local.project}-${local.env}-lambda-dlq"
      Environment = local.env
      Purpose     = "Lambda-Dead-Letter-Queue"
    }
  }
}

unit "api_gateway_logs" {
  source = "../../../../../units/cloudwatch-log-group"
  path   = "api-gateway-logs"

  values = {
    name = "/aws/apigateway/${local.project}-${local.env}-api"
    
    retention_in_days = 14
    
    kms_key_id = "alias/${local.project}/${local.env}/serverless"
    
    tags = {
      Name        = "${local.project}-${local.env}-api-logs"
      Environment = local.env
      Purpose     = "API-Gateway-Logs"
    }
  }
}
{{ end }}
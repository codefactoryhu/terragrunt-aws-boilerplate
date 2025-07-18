locals {
  env    = "development"
  region = "us-east-1"
  project = "my-project"
  
  tags = {
    Project     = local.project
    Environment = local.env
    ManagedBy   = "Terragrunt"
  }
}

{{- if has "vpc" .Units }}
unit "vpc" {
  source = "../../units/vpc"
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

    {{- if has "eks" .Units }}
    cluster_name = "${local.project}-${local.env}-cluster"
    {{- end }}
    {{- if has "rds-lambda" .Units }}
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
    {{- end }}
    
    tags = merge(local.tags, {
      Name = "${local.project}-${local.env}-vpc"
    })
  }
}
{{- end }}

{{- if has "kms" .Units }}
unit "kms" {
  source = "../../units/kms"
  path   = "kms"

  values = {
    description = "KMS key for encryption"
    aliases     = ["alias/${local.project}-encryption"]

    key_administrators = [
      "arn:aws:iam::123456789012:root",
      "arn:aws:iam::123456789012:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = merge(local.tags, {
      Name    = "${local.project}-kms-key"
      Purpose = "Encryption"
    })
  }
}
{{- end }}

{{- if has "route53-zones" .Units }}
unit "route53_zones" {
  source = "../../units/route53-zones"
  path   = "route53-zones"

  values = {
    zones = {
      "example.com" = {
        comment = "Hosted zone for example.com"
        tags = {
          Name = "example.com"
        }
      }
    }

    tags = merge(local.tags, {
      Name = "${local.project}-dns-zones"
    })
  }
}
{{- end }}

{{- if has "acm" .Units }}
unit "acm" {
  source = "../../units/acm"
  path   = "acm"

  values = {
    {{- if has "route53-zones" .Units }}
    route53_path = "../route53-zones"
    {{- end }}
    domain_name               = "example.com"
    subject_alternative_names = ["www.example.com"]
    wait_for_validation       = true

    tags = merge(local.tags, {
      Name = "${local.project}-ssl"
    })
  }
}
{{- end }}

{{- if has "webacl" .Units }}
unit "webacl" {
  source = "../../units/webacl"
  path   = "webacl"

  values = {
    name  = "${local.project}-waf"
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

    tags = merge(local.tags, {
      Name = "${local.project}-waf"
    })
  }
}
{{- end }}

{{- if has "s3" .Units }}
unit "s3" {
  source = "../../units/s3"
  path   = "s3"

  values = {
    bucket_name = "${local.project}-bucket-${random_string.bucket_suffix.result}"

    website = {
      index_document = "index.html"
      error_document = "error.html"
    }

    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false

    attach_policy = true
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "PublicReadGetObject"
          Effect    = "Allow"
          Principal = "*"
          Action    = "s3:GetObject"
          Resource  = "arn:aws:s3:::${local.project}-bucket-${random_string.bucket_suffix.result}/*"
        }
      ]
    })

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

    tags = merge(local.tags, {
      Name = "${local.project}-bucket"
    })
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
{{- end }}

{{- if has "cloudfront" .Units }}
unit "cloudfront" {
  source = "../../units/cloudfront"
  path   = "cloudfront"

  values = {
    {{- if has "s3" .Units }}
    s3_path = "../s3"
    {{- end }}
    {{- if has "webacl" .Units }}
    webacl_path = "../webacl"
    enable_waf  = true
    {{- end }}
    {{- if has "acm" .Units }}
    acm_path               = "../acm"
    use_custom_certificate = true
    aliases                = ["www.example.com", "example.com"]
    {{- end }}
    
    comment = "CloudFront distribution for ${local.project}"

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

    tags = merge(local.tags, {
      Name = "${local.project}-cloudfront"
    })
  }
}
{{- end }}

{{- if has "route53" .Units }}
unit "route53_records" {
  source = "../../units/route53"
  path   = "route53-records"

  values = {
    {{- if has "cloudfront" .Units }}
    cloudfront_path = "../cloudfront"
    {{- end }}
    {{- if has "route53-zones" .Units }}
    hosted_zone_id = "dependency.route53_zones.zone_id"
    {{- else }}
    hosted_zone_id = "<ACTUAL ZONE ID>"  # Replace with actual zone ID
    {{- end }}

    domain_names = ["example.com", "www.example.com"]
    enable_ipv6  = true

    additional_records = [
      {
        {{- if has "route53-zones" .Units }}
        zone_id = "dependency.route53_zones.zone_id"
        {{- else }}
        zone_id = "<ACTUAL ZONE ID>"  # Replace with actual zone ID
        {{- end }}
        name    = "example.com"
        type    = "MX"
        ttl     = 300
        records = ["10 mail.example.com"]
      }
    ]

    tags = merge(local.tags, {
      Name = "${local.project}-dns-records"
    })
  }
}
{{- end }}

{{- if has "secrets-manager" .Units }}
unit "secrets_manager" {
  source = "../../units/secrets-manager"
  path   = "secrets-manager"

  values = {
    name        = "${local.project}-${local.env}-secrets"
    description = "Application secrets"

    secret_string = jsonencode({
      username = "admin"
      password = "MySecurePassword123!"
      {{- if has "rds-lambda" .Units }}
      engine = "mysql"
      host   = "dependency.rds.endpoint"
      port   = 3306
      dbname = "appdb"
      {{- end }}
    })

    enable_rotation = false

    recovery_window_in_days = 7
    ignore_secret_changes   = true

    block_public_policy = true

    tags = merge(local.tags, {
      Name    = "${local.project}-secrets"
      Purpose = "Application-Secrets"
    })
  }
}
{{- end }}

{{- if has "rds-lambda" .Units }}
unit "rds" {
  source = "../../units/rds-lambda"
  path   = "rds"

  values = {
    {{- if has "vpc" .Units }}
    vpc_path = "../vpc"
    {{- end }}
    {{- if has "secrets-manager" .Units }}
    secrets_manager_path = "../secrets-manager"
    {{- end }}

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
    username = "admin"

    manage_master_user_password = true

    create_db_parameter_group = true
    create_db_option_group    = false

    backup_retention_period = 7
    backup_window           = "03:00-04:00"
    maintenance_window      = "sun:04:00-sun:05:00"

    monitoring_interval    = 60
    create_monitoring_role = true

    performance_insights_enabled          = true
    performance_insights_retention_period = 7

    multi_az            = false
    deletion_protection = false
    skip_final_snapshot = true

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

    tags = merge(local.tags, {
      Name    = "${local.project}-database"
      Purpose = "Application-Database"
    })
  }
}
{{- end }}

{{- if has "lambda" .Units }}
unit "lambda" {
  source = "../../units/lambda"
  path   = "lambda"

  values = {
    {{- if has "vpc" .Units }}
    vpc_path = "../vpc"
    {{- end }}
    {{- if has "rds-lambda" .Units }}
    rds_path = "../rds"
    {{- end }}
    {{- if has "secrets-manager" .Units }}
    secrets_manager_path = "../secrets-manager"
    {{- end }}

    function_name = "${local.project}-function"
    description   = "Main application function"
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.11"
    timeout       = 30
    memory_size   = 512

    source_path    = "./src"
    create_package = true

    environment_variables = {
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = local.env
      APP_NAME    = "${local.project}-function"
      {{- if has "rds-lambda" .Units }}
      DB_CONNECTION_POOL = "10"
      {{- end }}
    }

    reserved_concurrent_executions = -1
    layers = []

    cloudwatch_logs_retention_in_days = 14
    tracing_config_mode = "Active"

    tags = merge(local.tags, {
      Name    = "${local.project}-function"
      Purpose = "Application-Function"
    })
  }
}
{{- end }}

{{- if has "api-gateway" .Units }}
unit "api_gateway" {
  source = "../../units/api-gateway"
  path   = "api-gateway"

  values = {
    {{- if has "lambda" .Units }}
    lambda_path = "../lambda"
    {{- end }}

    name        = "${local.project}-api"
    description = "HTTP API for ${local.project}"

    cors_configuration = {
      allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
      allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      allow_origins     = ["*"]
      expose_headers    = ["date", "keep-alive"]
      max_age           = 86400
      allow_credentials = false
    }

    default_route_settings = {
      detailed_metrics_enabled = true
      throttling_burst_limit   = 1000
      throttling_rate_limit    = 500
    }

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

    tags = merge(local.tags, {
      Name    = "${local.project}-api"
      Purpose = "Application-API"
    })
  }
}
{{- end }}

{{- if has "eks" .Units }}
unit "eks" {
  source = "../../units/eks"
  path   = "eks"

  values = {
    {{- if has "vpc" .Units }}
    vpc_path = "../vpc"
    {{- end }}
    {{- if has "kms" .Units }}
    kms_path = "../kms"
    {{- end }}

    cluster_name    = "${local.project}-cluster"
    cluster_version = "1.31"

    enable_auto_mode              = false
    bootstrap_self_managed_addons = false

    cluster_endpoint_public_access       = true
    cluster_endpoint_private_access      = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

    authentication_mode = "API_AND_CONFIG_MAP"

    access_entries = {
      admin = {
        principal_arn     = "arn:aws:iam::123456789012:role/eks-admin-role"
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

    {{- if has "kms" .Units }}
    enable_kms_encryption = true
    {{- end }}

    cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    cloudwatch_log_group_retention_in_days = 14
    create_cloudwatch_log_group            = true

    cluster_security_group_additional_rules = {}
    node_security_group_additional_rules    = {}

    tags = merge(local.tags, {
      Name    = "${local.project}-cluster"
      Purpose = "EKS-Cluster"
    })
  }
}
{{- end }}

{{- if has "ebs-csi-driver" .Units }}
unit "ebs_csi_driver" {
  source = "../../units/ebs-csi-driver"
  path   = "ebs-csi-driver"

  values = {
    {{- if has "eks" .Units }}
    eks_path = "../eks"
    {{- end }}
    {{- if has "kms" .Units }}
    kms_path = "../kms"
    {{- end }}

    role_name                  = "ebs-csi-driver-role"
    namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]

    {{- if has "kms" .Units }}
    enable_kms_encryption = true
    {{- end }}

    tags = merge(local.tags, {
      Name    = "ebs-csi-driver-role"
      Purpose = "EBS-CSI-Driver"
    })
  }
}
{{- end }}

{{- if has "aws-lbc" .Units }}
unit "aws_load_balancer_controller" {
  source = "../../units/aws-lbc"
  path   = "aws-load-balancer-controller"

  values = {
    {{- if has "eks" .Units }}
    eks_path = "../eks"
    {{- end }}

    helm_chart_name         = "aws-load-balancer-controller"
    helm_chart_release_name = "aws-load-balancer-controller"
    helm_chart_repo         = "https://aws.github.io/eks-charts"
    helm_chart_version      = "1.8.4"

    namespace            = "kube-system"
    service_account_name = "aws-load-balancer-controller"

    irsa_role_name_prefix = "aws-load-balancer-controller"

    helm_chart_values = [
      <<-EOT
      clusterName: ${local.project}-cluster
      serviceAccount:
        create: true
        name: aws-load-balancer-controller
      region: ${local.region}
      vpcId: vpc-placeholder
      EOT
    ]

    tags = merge(local.tags, {
      Name    = "aws-load-balancer-controller"
      Purpose = "Load-Balancer-Controller"
    })
  }
}
{{- end }}

{{- if has "iam-role" .Units }}
unit "additional_iam_roles" {
  source = "../../units/iam-role"
  path   = "additional-iam-roles"

  values = {
    {{- if has "eks" .Units }}
    eks_path = "../eks"
    {{- end }}

    role_name = "additional-service-role"

    namespace_service_accounts = ["kube-system:additional-service"]

    attach_external_dns_policy = true

    role_policy_arns = {}

    tags = merge(local.tags, {
      Name    = "additional-service-role"
      Purpose = "Additional-Service"
    })
  }
}
{{- end }}

{{- if has "cloudwatch-log-group" .Units }}
unit "cloudwatch_log_group" {
  source = "../../units/cloudwatch-log-group"
  path   = "cloudwatch-log-group"

  values = {
    log_groups = {
      application = {
        name              = "/aws/lambda/${local.project}-${local.env}"
        retention_in_days = 14
        tags = {
          Application = local.project
          Environment = local.env
        }
      }
      {{- if has "api-gateway" .Units }}
      api_gateway = {
        name              = "/aws/apigateway/${local.project}-${local.env}"
        retention_in_days = 14
        tags = {
          Application = local.project
          Environment = local.env
        }
      }
      {{- end }}
    }

    tags = merge(local.tags, {
      Name    = "${local.project}-log-groups"
      Purpose = "Centralized-Logging"
    })
  }
}
{{- end }}

{{- if has "kms-serverless" .Units }}
unit "kms_serverless" {
  source = "../../units/kms-serverless"
  path   = "kms-serverless"

  values = {
    description = "KMS key for serverless applications"
    aliases     = ["alias/${local.project}-serverless"]

    key_administrators = [
      "arn:aws:iam::123456789012:root",
      "arn:aws:iam::123456789012:role/terragrunt-execution-role"
    ]

    deletion_window_in_days = 7

    tags = merge(local.tags, {
      Name    = "${local.project}-serverless-kms"
      Purpose = "Serverless-Encryption"
    })
  }
}
{{- end }}

{{- if has "security-group" .Units }}
unit "security_group" {
  source = "../../units/security-group"
  path   = "security-group"

  values = {
    {{- if has "vpc" .Units }}
    vpc_path = "../vpc"
    {{- end }}

    security_groups = {
      web = {
        name        = "${local.project}-web-sg"
        description = "Security group for web servers"
        ingress_rules = [
          {
            from_port   = 80
            to_port     = 80
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
            description = "HTTP"
          },
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
            description = "HTTPS"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["0.0.0.0/0"]
            description = "All outbound"
          }
        ]
      }
      {{- if has "rds-lambda" .Units }}
      database = {
        name        = "${local.project}-db-sg"
        description = "Security group for database"
        ingress_rules = [
          {
            from_port                = 3306
            to_port                  = 3306
            protocol                 = "tcp"
            source_security_group_id = "sg-lambda"
            description              = "MySQL from Lambda"
          }
        ]
        egress_rules = []
      }
      {{- end }}
    }

    tags = merge(local.tags, {
      Name    = "${local.project}-security-groups"
      Purpose = "Network-Security"
    })
  }
}
{{- end }}

{{- if has "sqs-dlq" .Units }}
unit "sqs_dlq" {
  source = "../../units/sqs-dlq"
  path   = "sqs-dlq"

  values = {
    {{- if has "kms-serverless" .Units }}
    kms_path = "../kms-serverless"
    {{- end }}

    queue_name = "${local.project}-${local.env}-queue"
    
    visibility_timeout_seconds = 30
    message_retention_seconds  = 1209600  # 14 days
    max_message_size          = 262144   # 256 KB
    delay_seconds             = 0
    receive_wait_time_seconds = 0

    dlq_name                    = "${local.project}-${local.env}-dlq"
    dlq_message_retention_seconds = 1209600  # 14 days
    max_receive_count           = 3

    {{- if has "kms-serverless" .Units }}
    enable_encryption = true
    {{- end }}

    tags = merge(local.tags, {
      Name    = "${local.project}-sqs-queue"
      Purpose = "Message-Queue"
    })
  }
}
{{- end }}
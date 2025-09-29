locals {
  env         = "dev"
  region      = "{{.DevelopmentRegion}}"
  project     = "{{.ProjectName}}"
  account_id  = "{{.DevelopmentAccountId}}"

  organization_id           = "{{.OrganizationId}}"
  organization_root_id      = "{{.OrganizationRootId}}"

  project_version = "{{.ProjectVersion}}"
  iam_role        = "arn:aws:iam::${local.account_id}:role/terragrunt-execution-role"

  # Skip modules
  skip_module = {
  {{ if or (eq .InfrastructurePreset "eks-managed") (eq .InfrastructurePreset "micro") }}
    cross-account         = true
    ebs-csi               = false
    irsa                  = false
    lbc                   = false
  {{ end }}
    eks                   = false
    vpc                   = false
  }
  # VPC
  vpc_name = "${local.project}-${local.env}-vpc"
  vpc_cidr = "10.0.0.0/16"

  vpc_azs             = ["${local.region}a", "${local.region}b"]
  vpc_private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  vpc_public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  vpc_enable_nat_gateway     = true
  vpc_single_nat_gateway     = true

  vpc_enable_flow_log                      = false
  vpc_create_flow_log_cloudwatch_iam_role  = false
  vpc_create_flow_log_cloudwatch_log_group = false

  vpc_cluster_name = "${local.env}-${local.project}-eks"
  {{ if or (eq .InfrastructurePreset "eks-managed") (eq .InfrastructurePreset "micro") }}
  #CROSS_ACCOUNT_ROLE
  cross_account_role_trusted_account_arn         = "arn:aws:iam::<ACCOUNT_ID>:role/aws-reserved/sso.amazonaws.com/eu-central-1/<ROLE_NAME>"
  cross_account_role_name = "eks-cross-account-access"

  # EKS
  eks_name               = "${local.env}-${local.project}-eks"
  eks_kubernetes_version = "1.33"

  eks_endpoint_public_access                   = true
  eks_enable_cluster_creator_admin_permissions = true
  eks_authentication_mode                      = "API"

  eks_access_entries = {
    test = {
      principal_arn = "arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/${local.region}/<ROLE_NAME>"

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
    cross-account = {
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

  eks_instance_types = ["t3.medium"]
  eks_min_size       = 1
  eks_max_size       = 3
  eks_desired_size   = 2

  #EBS_IRSA
  ebs_irsa_role_name                  = "${local.project}-${local.env}-ebs-irsa"
  ebs_irsa_namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
  ebs_irsa_attach_ebs_csi_policy = true

  # EBS CSI Addon
  ebs_csi_addon_name    = "aws-ebs-csi-driver"
  ebs_csi_addon_version = "v1.48.0-eksbuild.1"

  # Load Balancer Controller
  lbc_enable_aws_load_balancer_controller = true
  {{ end }}
  {{ if eq .InfrastructurePreset "eks-auto" }}
  #EKS
  eks_name               = "${local.env}-${local.project}-eks"
  eks_kubernetes_version = "1.33"

  eks_endpoint_public_access                   = true
  eks_enable_cluster_creator_admin_permissions = true

  eks_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  eks_access_entries = {
    test = {
      principal_arn = "arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/${local.region}/<ROLE_NAME>"

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
  {{ end }}
  {{ if eq .InfrastructurePreset "micro" }}
  # ACM
  acm_domain_name  = "my-domain.com"
  acm_zone_id      = "Z2ES7B9AZ6SHAE"

  acm_validation_method = "DNS"

  acm_subject_alternative_names = [
    "*.my-domain.com",
    "app.sub.my-domain.com",
  ]

  acm_wait_for_validation = true
  {{ end }}
  tags = {
    Name            = "${local.env}-${local.project}"
    Environment     = "${local.env}"
    Project         = "${local.project}"
    Project-version = "${local.project_version}"
  }
}

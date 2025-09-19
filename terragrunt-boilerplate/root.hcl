remote_state {
  backend     = "s3"
  generate    = {
    path      = "state.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    key             = "${path_relative_to_include()}/terraform.tfstate"
    bucket          = "codefactory-terragrunt-state"
    region          = "eu-west-2"
    encrypt         = true
    dynamodb_table  = "codefactory-terragrunt-lock-table"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region  = "eu-west-2"
  assume_role {
    role_arn = "arn:aws:iam::500286922458:role/terragrunt"
  }
}
EOF
}

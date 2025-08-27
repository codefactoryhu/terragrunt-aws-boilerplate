include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-cloudfront?ref=v5.0.0"
}

dependency "acm" {
  config_path = values.acm_path
  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  }
}

dependency "s3" {
  config_path = values.s3_path
  mock_outputs = {
    s3_bucket_bucket_domain_name = "mock-bucket.s3.amazonaws.com"
    s3_bucket_id                 = "mock-bucket"
    s3_bucket_arn                = "arn:aws:s3:::mock-bucket"
  }
}

dependency "webacl" {
  config_path = values.webacl_path
  mock_outputs = {
    web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mock/12345678-1234-1234-1234-123456789012"
  }
}

inputs = {
  aliases = values.aliases

  comment         = "CloudFront distribution for ${dependency.s3.outputs.s3_bucket_id}"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"

  origin = {
    s3_bucket = {
      domain_name           = dependency.s3.outputs.s3_bucket_bucket_domain_name
      origin_access_control = "s3_bucket"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_bucket"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = false
    cookies_forward = "none"
    headers         = []

    min_ttl     = try(values.min_ttl, 0)
    default_ttl = try(values.default_ttl, 3600)
    max_ttl     = try(values.max_ttl, 86400)
  }

  ordered_cache_behavior = try(values.ordered_cache_behavior, [])

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

  create_origin_access_control = true
  origin_access_control = {
    s3_bucket = {
      description      = "S3 bucket OAC for ${dependency.s3.outputs.s3_bucket_id}"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  create_origin_access_identity = false
  origin_access_identities      = {}

  viewer_certificate = {
    acm_certificate_arn = dependency.acm.outputs.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  geo_restriction = {
    restriction_type = "none"
  }

  web_acl_id = dependency.webacl.outputs.web_acl_arn

  logging_config = {}

  default_root_object = "index.html"

  tags = try(values.tags, {})
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# lambda

resource "aws_iam_role" "website_lambda_role" {
  name = "${var.env}-${var.website_name}-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "website_lambda_role_policy" {
  name = "${var.env}-${var.website_name}-lambda-policy"
  role = aws_iam_role.website_lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "website_lambda" {
  function_name = "${var.env}-${var.website_name}-lambda"
  role          = aws_iam_role.website_lambda_role.arn
  filename      = var.lambda_filename
  handler       = var.lambda_handler
  publish       = true

  source_code_hash = filebase64sha256(var.lambda_filename)

  environment {
    variables = var.lambda_environment_variables  
  }

  runtime     = var.lambda_runtime
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
}

# cerificate

resource "aws_acm_certificate" "website_certificate" {
  domain_name = var.env == "prod" ? "*.${var.website_domain}" : "*.${var.env}.${var.website_domain}"
  validation_method = "DNS"

  subject_alternative_names = [var.env == "prod" ? var.website_domain : "${var.env}.${var.website_domain}"]
}

resource "aws_route53_record" "website_record_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website_certificate.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
  zone_id = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "website_certificate_validation" {
  certificate_arn         = aws_acm_certificate.website_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.website_record_validation : record.fqdn]
}

# cloudfront

resource "aws_cloudfront_distribution" "website_distribution" {
  price_class = var.cloudfront_price_class

  origin {
    domain_name = var.env == "prod" ? var.website_domain : "${var.env}.${var.website_domain}"
    origin_id   = "website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2", "SSLv3", "TLSv1"]
    }
  }

  tags = {
    site        = "${var.env}.${var.website_domain}"
    environment = var.env
  }

  aliases             = var.env == "prod" ? [var.website_domain, "www.${var.website_domain}"] : ["${var.env}.${var.website_domain}", "www.${var.env}.${var.website_domain}"]
  default_root_object = "index.html"
  enabled             = "true"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "website"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.website_lambda.qualified_arn
      include_body = true
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = "true"
    min_ttl                = 0

    # default cache time in seconds.  This is 1 day, meaning CloudFront will only
    # look at your S3 bucket for changes once per day.
    default_ttl = 86400
    max_ttl     = 604800
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.website_certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_lambda_permission" "website_installer" {
  statement_id  = "${var.env}-${var.website_name}-lambda-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.website_lambda.function_name
  qualifier     = aws_lambda_function.website_lambda.version
  principal     = "edgelambda.amazonaws.com"
  source_arn = aws_cloudfront_distribution.website_distribution.arn
}

resource "aws_route53_record" "website_installer_domain" {
  name            = var.env == "prod" ? "${var.website_domain}." : "${var.env}.${var.website_domain}."
  zone_id         = var.route53_zone_id
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

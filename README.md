# terraform-aws-cloudfront
AWS CloudFront Terraform Module

## Usage

### Terraform

```hcl
module "cloudfront" {
  source = "github.com/aux4/terraform-aws-cloudfront?ref=v1"

  env = var.env
  aws_profile = var.aws_profile

  website_name = "your website name"
  website_domain = "yourdomain.com"

  lambda_filename = "../function.zip" # default value
  lambda_handler = "index.handler" # default value
  lambda_runtime = "nodejs22.x" # default value
  lambda_memory_size = 128 # default value
  lambda_timeout = 15 # default value

  cloudfront_price_class = "PriceClass_All" # default value
  
  route53_zone_id = "<YOUR ROUTE53 ZONE ID>"
}
```

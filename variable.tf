variable "env" {
  description = "The environment"
  type        = string
}

variable "aws_profile" {
  description = "The AWS profile to use"
  type        = string
}

variable "website_name" {
  description = "The name of the website"
  type        = string
}

variable "website_domain" {
  description = "The domain of the website"
  type        = string
}

variable "lambda_filename" {
  description = "The filename of the Lambda function"
  type        = string
  default     = "../function.zip"
}

variable "lambda_handler" {
  description = "The handler for the Lambda function"
  type        = string
  default     = "index.handler"

}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
  default     = "nodejs22.x"
}

variable "lambda_memory_size" {
  description = "The memory size for the Lambda function"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "The timeout for the Lambda function"
  type        = number
  default     = 15
}

variable "cloudfront_price_class" {
  description = "The CloudFront price class"
  type        = string
  default     = "PriceClass_All"
}

variable "route53_zone_id" {
  description = "The Route 53 zone ID"
  type        = string
}

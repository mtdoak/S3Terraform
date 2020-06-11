provider "aws" {
  region = "us-east-1"
}

// Variables for tfvars file

variable "www_domain_name" {
  type = string
  description = "Domain Name where S3 bucket should be pointed"
}

variable "root_domain_name" {
 type = string
 description = "Domain for Route53 A record"
}

variable "awscertarn" {
 type = string
 description = "AWS Cert ARN"
}

variable "hostingzoneid"{
 type = string
 description = "Route 53 Hosting Zone ID for A record"
 default = "Z09358402UHBKU59BTIHX"
}


// S3 Bucket Resource

resource "aws_s3_bucket" "www" {
  bucket = "${var.www_domain_name}"
  acl    = "public-read"
  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"AddPerm",
      "Effect":"Allow",
      "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${var.www_domain_name}/*"]
    }
  ]
}
POLICY

  website {
    index_document = "hello_world_take_home.html"
  }
}

// Uploading single file for site

resource "aws_s3_bucket_object" "file" {
  bucket = "${aws_s3_bucket.www.bucket}"
  source = "source/hello_world_take_home.html"
  key = "hello_world_take_home.html"
  content_type = "text/html"
}


//CloudFront Resource

resource "aws_cloudfront_distribution" "www_distribution" {

  origin {
   custom_origin_config {
     http_port              = "80"
     https_port             = "443"
     origin_protocol_policy = "http-only"
     origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  domain_name = "${aws_s3_bucket.www.website_endpoint}"
  origin_id   = "${var.www_domain_name}"
  }

  enabled 	=  true
  default_root_object = "hello_world_take_home.html"


   default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.www_domain_name}"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  aliases = ["${var.www_domain_name}"]
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

    viewer_certificate {
    acm_certificate_arn = "${var.awscertarn}"
    ssl_support_method  = "sni-only"
  }
}


// This Route53 record pointing to CloudFront distribution.

resource "aws_route53_record" "www" {
  zone_id = "${var.hostingzoneid}"
  name    = "${var.www_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.www_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.www_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

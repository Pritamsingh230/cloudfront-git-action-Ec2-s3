provider "aws" {
  region = "us-east-1"  # Update with your desired region
}

# 1. Create an EC2 instance
resource "aws_instance" "web_server" {
  ami           = "ami-005fc0f236362e99f"  # Replace with your preferred AMI ID
  instance_type = "t2.micro"

  tags = {
    Name = "Terraform-EC2"
  }
}

# 2. Create an S3 bucket
resource "aws_s3_bucket" "project_bucket" {
  bucket = "project-s3-bucket-2test33-test3"  # Hardcoded bucket name

  tags = {
    Name = "project-s3-bucket-2test33-test3"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "project_bucket_block" {
  bucket = aws_s3_bucket.project_bucket.id

  block_public_acls       = true   # Block public ACLs
  block_public_policy     = true   # Block public bucket policies
  ignore_public_acls      = true   # Ignore public ACLs
  restrict_public_buckets = true   # Restrict public buckets
}

# Upload files to the S3 bucket
resource "aws_s3_object" "project_files" {
  for_each = fileset("${path.module}/project_files", "*")
  bucket   = aws_s3_bucket.project_bucket.id
  key      = each.value
  source   = "${path.module}/project_files/${each.value}"
  acl      = "private"  # Ensure uploaded files are private
}

# 3. Create an Origin Access Control (OAC) for CloudFront to access S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                        = "s3-oac-for-cloudfront"
  description                 = "OAC to allow CloudFront access to S3"
  signing_behavior            = "always"  # CloudFront will sign requests for S3
  signing_protocol            = "sigv4"
  origin_access_control_origin_type = "s3"
}

# 4. Create a CloudFront distribution with the OAC attached
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.project_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.project_bucket.id}"

    # Attach the Origin Access Control (OAC) to CloudFront
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"  # Ensure the root object is index.html

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.project_bucket.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "CloudFront Distribution"
  }
}

# Output the CloudFront URL
output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

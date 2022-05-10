# MIT License
#
# Copyright (c) 2022 Martin Macecek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.13.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region  = var.aws_region
}

provider "aws" {
  alias      = "acm_provider"
  region     = "us-east-1"
}

locals {
    is_arm_supported_region = contains(["us-east-1", "us-west-2", "eu-central-1", "eu-west-1", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"], data.aws_region.current.name)
    os_cognito_user_pool_pre_signup_lambda_function_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoUserPoolPreSignUp"
}

resource "random_string" "unique_id" {
    count   = var.resource_prefix == "" ? 1 : 0
    length  = 8
    special = false  
}

resource "aws_iam_role" "os_cognito_user_pool_pre_signup_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchCognitoUserPoolPreSignUpRole" : null
    managed_policy_arns = [
        "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    ]
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            },
        ]
    })
}

resource "aws_cloudwatch_log_group" "os_cognito_user_pool_pre_signup_log_group" {
    name = "/aws/lambda/${local.os_cognito_user_pool_pre_signup_lambda_function_name}"
    retention_in_days = 7
}

resource "aws_lambda_function" "os_cognito_user_pool_pre_signup" {
    depends_on = [
        aws_cloudwatch_log_group.os_cognito_user_pool_pre_signup_log_group
    ]
    function_name = "${local.os_cognito_user_pool_pre_signup_lambda_function_name}"
    architectures = local.is_arm_supported_region ? ["arm64"] : ["x86_64"]
    filename = "${path.module}/.package/email_pre_signup.zip"
    handler = "email_pre_signup.lambda_handler"
    runtime = "python3.9"
    memory_size = 128
    timeout = 60
    role = aws_iam_role.os_cognito_user_pool_pre_signup_role.arn
    environment {
      variables = {
        "LOG_LEVEL" = "info",
        "EMAIL_VALIDATION_REGEX" = "${var.os_dashboards_allowed_email_signup_regex}",
        "AUTO_CONFIRM_USER" = "${tostring(var.os_dashboards_auto_confirm_user)}"
      }
    }
}

resource "aws_cognito_user_pool" "os_cognito_user_pool" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoUserPool"
    account_recovery_setting {
        recovery_mechanism {
            name     = "verified_email"
            priority = 1
        }
    }
    admin_create_user_config {
        allow_admin_create_user_only = false
    }
    auto_verified_attributes = [ "email" ]
    lambda_config {
        pre_sign_up = aws_lambda_function.os_cognito_user_pool_pre_signup.arn
    }
    password_policy {
        minimum_length                   = 8
        require_lowercase                = true
        require_numbers                  = true
        require_symbols                  = true
        require_uppercase                = true
        temporary_password_validity_days = 3
    }
    schema {
        attribute_data_type      = "String"
        developer_only_attribute = false
        mutable                  = true
        name                     = "email"
        required                 = true
        string_attribute_constraints {
            max_length = "2048"
            min_length = "0"
        }
    }
    username_attributes = [ "email" ]
    user_pool_add_ons {
        advanced_security_mode = "ENFORCED"
    }
    verification_message_template {
        default_email_option = "CONFIRM_WITH_CODE"
        email_message        = "The verification code to your new account is {####}"
        email_subject        = "Verify your new account"
        sms_message          = "The verification code to your new account is {####}"
    }
}

resource "aws_lambda_permission" "os_cognito_user_pool_pre_signup_permission" {
    statement_id  = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoUserPoolPreSignUpPermission"
    action        = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.os_cognito_user_pool_pre_signup.function_name}"
    principal     = "cognito-idp.amazonaws.com"
    source_arn    = "${aws_cognito_user_pool.os_cognito_user_pool.arn}"
}

resource "aws_cognito_user_pool_domain" "os_cognito_user_pool_domain" {
    domain       = var.os_domain_name
    user_pool_id = aws_cognito_user_pool.os_cognito_user_pool.id
}

resource "aws_cognito_user" "os_cognito_user_pool_admin_user" {
    user_pool_id = aws_cognito_user_pool.os_cognito_user_pool.id
    username     = "${var.os_admin_email}"
    attributes = {
      email = "${var.os_admin_email}"
    }
}

resource "aws_cognito_identity_pool" "os_cognito_identity_pool" {
    identity_pool_name               = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoIdentityPool"
    allow_unauthenticated_identities = false
}

resource "aws_iam_role" "os_cognito_authentication_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchCognitoAuthenticationRole" : null
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRoleWithWebIdentity"
                Condition = {
                    "StringEquals" = {
                        "cognito-identity.amazonaws.com:aud" = "${aws_cognito_identity_pool.os_cognito_identity_pool.id}"
                    },
                    "ForAnyValue:StringLike" = {
                        "cognito-identity.amazonaws.com:amr": "authenticated"
                    }
                }
                Effect = "Allow"
                Principal = {
                    Federated = "cognito-identity.amazonaws.com"
                }
            },
        ]
    })
}

resource "aws_cognito_identity_pool_roles_attachment" "os_cognito_authentication_role_attachment" {
  identity_pool_id = aws_cognito_identity_pool.os_cognito_identity_pool.id
  roles = {
    "authenticated" = aws_iam_role.os_cognito_authentication_role.arn
  }
}

resource "aws_iam_role" "os_cognito_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchCognitoRole" : null
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "es.amazonaws.com"
                }
            },
        ]
    })
}

resource "aws_iam_policy" "os_cognito_access_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoAccess"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action   = [
                    "cognito-idp:DescribeUserPool",
                    "cognito-idp:CreateUserPoolClient",
                    "cognito-idp:DeleteUserPoolClient",
                    "cognito-idp:DescribeUserPoolClient",
                    "cognito-idp:AdminInitiateAuth",
                    "cognito-idp:AdminUserGlobalSignOut",
                    "cognito-idp:ListUserPoolClients",
                    "cognito-identity:DescribeIdentityPool",
                    "cognito-identity:UpdateIdentityPool",
                    "cognito-identity:SetIdentityPoolRoles",
                    "cognito-identity:GetIdentityPoolRoles",
                ]
                Effect   = "Allow"
                Resource = "*"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "os_cognito_role_attachment_access" {
    role       = aws_iam_role.os_cognito_role.name
    policy_arn = aws_iam_policy.os_cognito_access_policy.arn
}

resource "aws_iam_policy" "os_cognito_default_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoRoleDefaultPolicy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action   = ["iam:PassRole"]
                Condition = {
                    "StringLike" = {
                        "iam:PassedToService" = "cognito-identity.amazonaws.com"
                    }
                }
                Effect   = "Allow"
                Resource = aws_iam_role.os_cognito_role.arn
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "os_cognito_role_attachment_default" {
    role       = aws_iam_role.os_cognito_role.name
    policy_arn = aws_iam_policy.os_cognito_default_policy.arn
}

resource "aws_iam_service_linked_role" "os_service_linked_role" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_iam_role" "kinesis_delivery_stream_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}KinesisDeliveryStreamRole" : null
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Federated = "firehose.amazonaws.com"
                }
            },
        ]
    })
}

resource "aws_acm_certificate" "os_custom_dashboards_certificate" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    provider          = aws.acm_provider
    domain_name       = "${var.os_domain_name}.${var.os_custom_dashboards_domain}"
    validation_method = "DNS"
}

resource "aws_route53_record" "os_custom_dashboard_certificate_validation_record" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    name    = "${aws_acm_certificate.os_custom_dashboards_certificate[count.index].domain_validation_options.0.resource_record_name}"
    type    = "${aws_acm_certificate.os_custom_dashboards_certificate[count.index].domain_validation_options.0.resource_record_type}"
    zone_id = "${data.aws_route53_zone.os_custom_dashboards_hosted_zone_id[count.index].zone_id}"
    records = [ "${aws_acm_certificate.os_custom_dashboards_certificate[count.index].domain_validation_options.0.resource_record_value}" ]
    ttl     = 60
}

resource "aws_acm_certificate_validation" "os_custom_dashboards_certificate_validation" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    provider                = aws.acm_provider
    certificate_arn         = aws_acm_certificate.os_custom_dashboards_certificate[count.index].arn
    validation_record_fqdns = [for record in aws_route53_record.os_custom_dashboard_certificate_validation_record : record.fqdn]
}

# resource "aws_elasticsearch_domain" "opensearch" {
#   domain_name           = var.os_domain_name
#   elasticsearch_version = "OpenSearch_${var.os_engine_version}"
#   access_policies       = data.aws_iam_policy_document.os_access_policy.json
# }
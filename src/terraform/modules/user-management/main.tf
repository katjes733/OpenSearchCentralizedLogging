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

# ##################################################################################################
# Resources for user management
# Mostly Cognito and and IAM role resources
# ##################################################################################################

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.13.0"
        }
    }

    required_version = ">= 0.14.9"
}

# ##################################################################################################
# Constants
# ##################################################################################################

data "aws_iam_policy_document" "opensearch_assume_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "es.amazonaws.com" ]            
        }
    }
}

resource "random_string" "unique_id" {
    count   = var.resource_prefix == "" ? 1 : 0
    length  = 8
    special = false
    upper   = false
}

# ##################################################################################################
# Resources
# ##################################################################################################

module "cognito_user_pool_pre_signup" {
    source = "../cognito-pre-signup"

    resource_prefix             = var.resource_prefix
    allowed_email_signup_regex  = var.allowed_email_signup_regex
    auto_confirm_user           = var.auto_confirm_user
}

resource "aws_cognito_user_pool" "cognito_user_pool" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoUserPool"
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
        pre_sign_up = module.cognito_user_pool_pre_signup.arn
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

resource "aws_lambda_permission" "cognito_user_pool_pre_signup_permission" {
    statement_id  = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoUserPoolPreSignUpPermission"
    action        = "lambda:InvokeFunction"
    function_name = "${module.cognito_user_pool_pre_signup.function_name}"
    principal     = "cognito-idp.amazonaws.com"
    source_arn    = "${aws_cognito_user_pool.cognito_user_pool.arn}"
}

resource "aws_cognito_user_pool_domain" "cognito_user_pool_domain" {
    domain       = var.domain_name
    user_pool_id = aws_cognito_user_pool.cognito_user_pool.id
}

resource "aws_cognito_user" "cognito_user_pool_admin_user" {
    user_pool_id = aws_cognito_user_pool.cognito_user_pool.id
    username     = "${var.admin_email}"
    attributes = {
      email = "${var.admin_email}"
    }
}

resource "aws_cognito_identity_pool" "cognito_identity_pool" {
    identity_pool_name               = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoIdentityPool"
    allow_unauthenticated_identities = false

    lifecycle {
        ignore_changes = [
            # Ignore changes to cognito_identity_providers, because opensearch will
            # update these during its deployment.
            cognito_identity_providers,
        ]
    }
}

data "aws_iam_policy_document" "cognito_authentication_assume_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRoleWithWebIdentity" ]
        condition {
            test     = "StringEquals"
            variable = "cognito-identity.amazonaws.com:aud"
            values   = [ "${aws_cognito_identity_pool.cognito_identity_pool.id}" ]
        }
        condition {
            test     = "ForAnyValue:StringLike"
            variable = "cognito-identity.amazonaws.com:amr"
            values   = [ "authenticated" ]
        }
        principals {
            type        = "Federated"
            identifiers = [ "cognito-identity.amazonaws.com" ]            
        }
    }
}

resource "aws_iam_role" "cognito_authentication_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}CognitoAuthenticationRole" : null
    assume_role_policy = data.aws_iam_policy_document.cognito_authentication_assume_role_policy_document.json
}

resource "aws_cognito_identity_pool_roles_attachment" "cognito_authentication_role_attachment" {
  identity_pool_id = aws_cognito_identity_pool.cognito_identity_pool.id
  roles = {
    "authenticated" = aws_iam_role.cognito_authentication_role.arn
  }
}

resource "aws_iam_role" "cognito_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}CognitoRole" : null
    assume_role_policy = data.aws_iam_policy_document.opensearch_assume_role_policy_document.json
}

data "aws_iam_policy_document" "cognito_access_policy_document" {
    statement {
        effect = "Allow"
        actions = [ 
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
        resources = [ "*" ]
    }
}

resource "aws_iam_policy" "cognito_access_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoAccess"
    policy = data.aws_iam_policy_document.cognito_access_policy_document.json
}

resource "aws_iam_role_policy_attachment" "cognito_role_attachment_access" {
    role       = aws_iam_role.cognito_role.name
    policy_arn = aws_iam_policy.cognito_access_policy.arn
}

data "aws_iam_policy_document" "cognito_default_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "iam:PassRole" ]
        resources = [ aws_iam_role.cognito_role.arn ]
        condition {
            test     = "StringLike"
            variable = "iam:PassedToService"
            values   = [ "cognito-identity.amazonaws.com" ]
        }
    }
}

resource "aws_iam_policy" "cognito_default_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoRoleDefaultPolicy"
    policy = data.aws_iam_policy_document.cognito_default_policy_document.json
}

resource "aws_iam_role_policy_attachment" "cognito_role_attachment_default" {
    role       = aws_iam_role.cognito_role.name
    policy_arn = aws_iam_policy.cognito_default_policy.arn
}

# ##################################################################################################
# Outputs
# ##################################################################################################

output "cognito_authentication_role_arn" {
    value       = aws_iam_role.cognito_authentication_role.arn
    description = "The ARN of the Cognito authentication role."
}

output "cognito_identity_pool_id" {
    value       = aws_cognito_identity_pool.cognito_identity_pool.id
    description = "The ID of the Cognito identity pool."
}

output "cognito_role_arn" {
    value       = aws_iam_role.cognito_role.arn
    description = "The ARN of the Cognito role."
}

output "cognito_user_pool_id" {
    value       = aws_cognito_user_pool.cognito_user_pool.id
    description = "The ID of the Cognito user pool."
}
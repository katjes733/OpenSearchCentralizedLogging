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
# Resources to validate user sign up for Cognito User Pool.
# Invoked by User Pool on pre-sign up and executed by Lambda function.
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

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "lambda.amazonaws.com" ]
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
# Conditions
# ##################################################################################################

locals {
    is_arm_supported_region = contains(["us-east-1", "us-west-2", "eu-central-1", "eu-west-1", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"], data.aws_region.current.name)
}

# ##################################################################################################
# Resources
# ##################################################################################################

resource "aws_iam_role" "cognito_user_pool_pre_signup_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}CognitoUserPoolPreSignUpRole" : null    
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "cognito_user_pool_pre_signup_role_attachment_basic" {
    role       = aws_iam_role.cognito_user_pool_pre_signup_role.name
    policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

locals {    
    cognito_user_pool_pre_signup_lambda_function_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CognitoUserPoolPreSignUp"    
}

resource "aws_cloudwatch_log_group" "cognito_user_pool_pre_signup_log_group" {
    name = "/aws/lambda/${local.cognito_user_pool_pre_signup_lambda_function_name}"
    retention_in_days = 7
    # kms_key_id = ...
}

data "archive_file" "email_pre_signup" {
    type = "zip"
    source_file = "${path.module}/python/email_pre_signup.py"
    output_path = "${path.module}/.package/email_pre_signup.zip"
}

resource "aws_lambda_function" "cognito_user_pool_pre_signup" {
    depends_on = [
        aws_cloudwatch_log_group.cognito_user_pool_pre_signup_log_group,
        aws_iam_role_policy_attachment.cognito_user_pool_pre_signup_role_attachment_basic
    ]
    function_name = "${local.cognito_user_pool_pre_signup_lambda_function_name}"
    architectures = local.is_arm_supported_region ? ["arm64"] : ["x86_64"]
    filename = "${path.module}/.package/email_pre_signup.zip"
    source_code_hash = data.archive_file.email_pre_signup.output_base64sha256
    handler = "email_pre_signup.lambda_handler"
    runtime = "python3.9"
    memory_size = 128
    timeout = 60
    role = aws_iam_role.cognito_user_pool_pre_signup_role.arn
    environment {
      variables = {
        "LOG_LEVEL" = "info",
        "EMAIL_VALIDATION_REGEX" = "${var.allowed_email_signup_regex}",
        "AUTO_CONFIRM_USER" = "${tostring(var.auto_confirm_user)}"
      }
    }
}

# ##################################################################################################
# Outputs
# ##################################################################################################

output "arn" {
    value = aws_lambda_function.cognito_user_pool_pre_signup.arn
    description = "The ARN of the Cognito User Pool Pre Sign Up Function."
}

output "function_name" {
    value = aws_lambda_function.cognito_user_pool_pre_signup.function_name
    description = "The Name of the Cognito User Pool Pre Sign Up Function."
}
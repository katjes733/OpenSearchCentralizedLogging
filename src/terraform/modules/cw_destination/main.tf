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

resource "random_string" "unique_id" {
    count   = var.resource_prefix == "" ? 1 : 0
    length  = 8
    special = false
    upper = false
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudwatch_assume_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "logs.amazonaws.com" ]
        }
    }
}

resource "aws_cloudwatch_log_destination" "os_cw_destination" {
    name       = var.destination_name
    role_arn   = var.cw_destination_role_arn
    target_arn = var.kinesis_stream_arn
}

data "aws_iam_policy_document" "os_cw_destination_policy_document" {
    statement {
        effect = "Allow"
        principals {
            type        = "AWS"
            identifiers = var.spoke_accounts == "" ? [ data.aws_caller_identity.current.account_id ] : split(",", var.spoke_accounts)
        }
        actions = [ "logs:PutSubscriptionFilter" ]
        resources = [ aws_cloudwatch_log_destination.os_cw_destination.arn ]
    }
}

resource "aws_cloudwatch_log_destination_policy" "os_cw_destination_policy" {
    destination_name = aws_cloudwatch_log_destination.os_cw_destination.name
    access_policy    = data.aws_iam_policy_document.os_cw_destination_policy_document.json
}
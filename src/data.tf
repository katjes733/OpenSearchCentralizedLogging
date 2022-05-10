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

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "archive_file" "email_pre_signup" {
    type = "zip"
    source_file = "${path.module}/python/email_pre_signup.py"
    output_path = "${path.module}/.package/email_pre_signup.zip"
}

data "aws_route53_zone" "os_custom_dashboards_hosted_zone_id" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    name  = "${var.os_custom_dashboards_domain}"
}

data "aws_iam_policy_document" "os_access_policy" {
    statement {
        actions = [
            "es:ESHttpGet",
            "es:ESHttpDelete",
            "es:ESHttpPut",
            "es:ESHttpPost",
            "es:ESHttpHead",
            "es:ESHttpPatch"
        ]
        resources = ["arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/*"]

        principals {
            type        = "AWS"
            identifiers = [ aws_iam_role.os_cognito_authentication_role.arn ]
        }
        dynamic "condition" {
            for_each = var.os_dashboards_allowed_cidrs != "" ? [1] : []

            content {
                test     = "IpAddress"
                variable = "aws:SourceIp"
                values   = split(",", var.os_dashboards_allowed_cidrs)
            }
        }
    }

    statement {
        actions = [
            "es:DescribeElasticsearchDomain",
            "es:DescribeElasticsearchDomains",
            "es:DescribeElasticsearchDomainConfig",
            "es:ESHttpPost",
            "es:ESHttpPut",
            "es:HttpGet"
        ]
        resources = ["arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/*"]

        principals {
            type        = "AWS"
            identifiers = [ aws_iam_role.kinesis_delivery_stream_role.arn ]
        }
    }
}
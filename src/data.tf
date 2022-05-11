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

data "archive_file" "log_data_transformer" {
    type = "zip"
    source_file = "${path.module}/python/log_data_transformer.py"
    output_path = "${path.module}/.package/log_data_transformer.zip"
}

data "aws_iam_policy_document" "lambda_assume_role_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "lambda.amazonaws.com" ]
        }
    }
}

data "aws_iam_policy_document" "firehose_assume_role_document" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "firehose.amazonaws.com" ]
        }
    }
}

data "aws_route53_zone" "os_custom_dashboards_hosted_zone_id" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    name  = "${var.os_custom_dashboards_domain}"
}

data "aws_iam_policy_document" "os_access_policy" {
    statement {
        effect = "Allow"
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
        effect = "Allow"
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
            identifiers = [ aws_iam_role.os_kinesis_delivery_stream_role.arn ]
        }
    }
}

data "aws_iam_policy_document" "os_log_resource_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "logs:PutLogEvents",
            "logs:PutLogEventsBatch",
            "logs:CreateLogStream"
        ]
        resources = ["arn:aws:logs:*"]

        principals {
            type        = "Service"
            identifiers = [ "es.amazonaws.com" ]
        }
    }
}

data "aws_iam_policy_document" "os_cognito_auth_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "es:ESHttpGet",
            "es:ESHttpDelete",
            "es:ESHttpPut",
            "es:ESHttpPost",
            "es:ESHttpHead",
            "es:ESHttpPatch"
        ]
        resources = [ aws_elasticsearch_domain.opensearch.arn ]
    }
}

data "aws_iam_policy_document" "os_kinesis_delivery_stream_backup_bucket_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "s3:Put*",
            "s3:Get*"
        ]
        principals {
            type        = "AWS"
            identifiers = [ aws_iam_role.os_kinesis_delivery_stream_role.arn ]
        }
        resources = [ 
            "${aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn}",
            "${aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn}/*" 
        ]
    }
}

data "aws_iam_policy_document" "os_kinesis_delivery_stream_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads"
        ]
        resources = [ 
            "${aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn}",
            "${aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn}/*" 
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "ec2:DescribeVpcs",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission",
            "ec2:DeleteNetworkInterface"
        ]
        resources = [ "*" ]
    }
    # TODO es:...
}

data "aws_iam_policy_document" "os_log_data_transformer_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "kinesis:DescribeStream",
            "kinesis:DescribeStreamSummary",
            "kinesis:GetRecords",
            "kinesis:GetShardIterator",
            "kinesis:SubscribeToShard"
        ]
        resources = [ aws_kinesis_stream.os_kinesis_data_stream.arn ]
    }

    statement {
        effect = "Allow"
        actions = [
            "kinesis:ListStreams",
            "kinesis:ListShards"
        ]
        resources = [ "*" ]
    }

    # statement {
    #     effect = "Allow"
    #     actions = [
    #         "firehose:PutRecordBatch"
    #     ]
    #     resources = [ aws_kinesis_firehose_delivery_stream.os_kinesis_delivery_stream.arn ]
    # }
}


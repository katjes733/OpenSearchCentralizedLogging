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

locals {
    default_tags = {
        Owner = var.tag_owner
        Type  = var.tag_type
        Usage = var.tag_usage
    }
}

locals {
    regions = var.spoke_regions == "" ? tolist(["all"]) : split(",", var.spoke_regions)
}

provider "aws" {
    region       = var.aws_region
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "acm_provider"
    region       = "us-east-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-northeast-1"
    region       = "ap-northeast-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-northeast-2"
    region       = "ap-northeast-2"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-northeast-3"
    region       = "ap-northeast-3"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-south-1"
    region       = "ap-south-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-southeast-1"
    region       = "ap-southeast-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ap-southeast-2"
    region       = "ap-southeast-2"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "ca-central-1"
    region       = "ca-central-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "eu-central-1"
    region       = "eu-central-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "eu-north-1"
    region       = "eu-north-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "eu-west-1"
    region       = "eu-west-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "eu-west-2"
    region       = "eu-west-2"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "eu-west-3"
    region       = "eu-west-3"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "sa-east-1"
    region       = "sa-east-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "us-east-1"
    region       = "us-east-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "us-east-2"
    region       = "us-east-2"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "us-west-1"
    region       = "us-west-1"
    default_tags {
        tags = local.default_tags
    }
}

provider "aws" {
    alias        = "us-west-2"
    region       = "us-west-2"
    default_tags {
        tags = local.default_tags
    }
}

resource "random_string" "unique_id" {
    count   = var.resource_prefix == "" ? 1 : 0
    length  = 8
    special = false
    upper = false
}

resource "aws_iam_service_linked_role" "os_service_linked_role" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_acm_certificate" "os_custom_dashboards_certificate" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    provider          = aws.acm_provider
    domain_name       = "${var.os_domain_name}.${var.os_custom_dashboards_domain}"
    validation_method = "DNS"
}

data "aws_route53_zone" "os_custom_dashboards_hosted_zone_id" {
    count = var.os_custom_dashboards_domain != "" ? 1 : 0
    name  = "${var.os_custom_dashboards_domain}"
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

resource "aws_cloudwatch_log_group" "os_index_slow_log_group" {
    name = "/aws/opensearch/%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchIndexSlowLogGroup"    
    retention_in_days = 30
    # kms_key_id = ...
}

resource "aws_cloudwatch_log_group" "os_search_slow_log_group" {
    name = "/aws/opensearch/%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchSearchSlowLogGroup"    
    retention_in_days = 30
    # kms_key_id = ...
}

resource "aws_cloudwatch_log_group" "os_application_log_group" {
    name = "/aws/opensearch/%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchApplicationLogGroup"    
    retention_in_days = 30
    # kms_key_id = ...
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

resource "aws_cloudwatch_log_resource_policy" "os_log_resource_policy" {
    policy_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchLogResourcePolicy"
    policy_document = data.aws_iam_policy_document.os_log_resource_policy_document.json
}

data "aws_iam_policy_document" "os_access_policy_document" {
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

resource "aws_elasticsearch_domain" "opensearch" {
    depends_on = [
        aws_cloudwatch_log_resource_policy.os_log_resource_policy,
        aws_iam_service_linked_role.os_service_linked_role
    ]
    domain_name           = var.os_domain_name
    elasticsearch_version = "OpenSearch_${var.os_engine_version}"
    access_policies       = data.aws_iam_policy_document.os_access_policy_document.json
    cluster_config {
        dedicated_master_enabled = local.use_master_node
        dedicated_master_count   = local.use_master_node ? lookup(local.os_sizing_master_count, var.os_size) : null
        dedicated_master_type    = local.use_master_node ? lookup(local.os_sizing_master_size, var.os_size) : null
        instance_count           = lookup(local.os_sizing_node_count, var.os_size)
        instance_type            = lookup(local.os_sizing_instance_size, var.os_size)
        zone_awareness_enabled   = var.os_multi_az
        dynamic "zone_awareness_config" {
            for_each = var.os_multi_az ? [1] : []

            content {
                availability_zone_count = 2
            }
        }
    }
    cognito_options {
        enabled           = true
        identity_pool_id  = aws_cognito_identity_pool.os_cognito_identity_pool.id
        role_arn          = aws_iam_role.os_cognito_role.arn
        user_pool_id      = aws_cognito_user_pool.os_cognito_user_pool.id
    }
    dynamic "domain_endpoint_options" {
        for_each = var.os_custom_dashboards_domain != "" ? [1] : []

        content {
            custom_endpoint_enabled         = true
            custom_endpoint                 = "${var.os_domain_name}.${var.os_custom_dashboards_domain}"
            custom_endpoint_certificate_arn = aws_acm_certificate.os_custom_dashboards_certificate.arn
            enforce_https                   = true
            tls_security_policy             = "Policy-Min-TLS-1-2-2019-07" 
        }
    }
    ebs_options {
        ebs_enabled = true
        volume_size = lookup(local.os_sizing_volume_size, var.os_size)
        volume_type = "gp2"
    }
    encrypt_at_rest {
        enabled = true
        # kms_key_id = ...
    }
    log_publishing_options {
        enabled                  = true
        log_type                 = "INDEX_SLOW_LOGS"
        cloudwatch_log_group_arn = aws_cloudwatch_log_group.os_index_slow_log_group.arn
    }

    log_publishing_options {
        enabled                  = true
        log_type                 = "SEARCH_SLOW_LOGS"
        cloudwatch_log_group_arn = aws_cloudwatch_log_group.os_search_slow_log_group.arn
    }

    log_publishing_options {
        enabled                  = true
        log_type                 = "ES_APPLICATION_LOGS"
        cloudwatch_log_group_arn = aws_cloudwatch_log_group.os_application_log_group.arn
    }
    node_to_node_encryption {
      enabled = true
    }
}

resource "aws_route53_record" "os_domain_dashboard_record_set" {
    count   = var.os_custom_dashboards_domain != "" ? 1 : 0
    zone_id = data.aws_route53_zone.os_custom_dashboards_hosted_zone_id[count.index].zone_id
    name    = "${var.os_domain_name}.${var.os_custom_dashboards_domain}"
    type    = "CNAME"
    ttl     = "300"
    records = [ aws_elasticsearch_domain.opensearch.endpoint ]
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

resource "aws_iam_policy" "os_cognito_auth_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoAuthenticationRolePolicy"
    policy = data.aws_iam_policy_document.os_cognito_auth_policy_document.json
}

resource "aws_iam_role_policy_attachment" "os_cognito_authentication_role_attachment" {
    role       = aws_iam_role.os_cognito_authentication_role.name
    policy_arn = aws_iam_policy.os_cognito_auth_policy.arn
}

# ##################################################################################################
# Resources for the Kinesis Delivery Stream used to forward transformed events to OpenSearch
# ##################################################################################################

resource "aws_iam_role" "os_kinesis_delivery_stream_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchKinesisDeliveryStreamRole" : null
    assume_role_policy = data.aws_iam_policy_document.firehose_assume_role_policy_document.json
}

resource "aws_s3_bucket" "os_kinesis_delivery_stream_backup_bucket_access_logs" {
    bucket        = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }kinesisdeliverystreambackupbucketaccesslogs"
    force_destroy = true
}

resource "aws_s3_bucket_acl" "os_kinesis_delivery_stream_backup_bucket_access_logs_acl" {
  bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket_access_logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "os_kinesis_delivery_stream_backup_bucket_access_logs_sse" {
    bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket_access_logs.bucket

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

resource "aws_s3_bucket_public_access_block" "os_kinesis_delivery_stream_backup_bucket_access_logs_block" {
    bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket_access_logs.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket" "os_kinesis_delivery_stream_backup_bucket" {
    bucket        = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }kinesisdeliverystreambackupbucket"
    force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "os_kinesis_delivery_stream_backup_bucket_sse" {
    bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.bucket

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

resource "aws_s3_bucket_logging" "os_kinesis_delivery_stream_backup_bucket_logging" {
  bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.id
  target_bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket_access_logs.id
  target_prefix = "os-access-logs/"
}

resource "aws_s3_bucket_public_access_block" "os_kinesis_delivery_stream_backup_bucket_block" {
    bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
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

resource "aws_s3_bucket_policy" "os_kinesis_delivery_stream_backup_bucket_policy" {
  bucket = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.id
  policy = data.aws_iam_policy_document.os_kinesis_delivery_stream_backup_bucket_policy_document.json
}

resource "aws_cloudwatch_log_group" "os_kinesis_delivery_stream_log_group" {
    name = "/aws/kinesisfirehose/%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchKinesisDeliveryStream"    
    retention_in_days = 30
    # kms_key_id = ...
}

resource "aws_cloudwatch_log_stream" "os_kinesis_delivery_stream_os_delivery_log_stream" {
    name           = "OpenSearchDelivery"
    log_group_name = aws_cloudwatch_log_group.os_kinesis_delivery_stream_log_group.name
}

resource "aws_cloudwatch_log_stream" "os_kinesis_delivery_stream_s3_delivery_log_stream" {
    name           = "S3Delivery"
    log_group_name = aws_cloudwatch_log_group.os_kinesis_delivery_stream_log_group.name
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

    statement {
        effect = "Allow"
        actions = [
            "es:DescribeElasticsearchDomain",
            "es:DescribeElasticsearchDomains",
            "es:DescribeElasticsearchDomainConfig",
            "es:ESHttpPost",
            "es:ESHttpPut"
        ]
        resources = [ 
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}",
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/*" 
        ]
    }

    statement {
        effect = "Allow"
        actions = [ "es:ESHttpGet" ]
        resources = [ 
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/_all/_settings",
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/_cluster/stats", 
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/${var.os_index_name}/_mapping/kinesis'",
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/_nodes", 
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/_nodes/*/stats",
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/_stats", 
            "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.os_domain_name}/${var.os_index_name}/_stats"
        ]
    }

    statement {
        effect = "Allow"
        actions = [ 
            "logs:PutLogEvents",
            "logs:CreateLogStream"
        ]
        resources = [ aws_cloudwatch_log_group.os_kinesis_delivery_stream_log_group.arn ]
    }

    statement {
        effect = "Allow"
        actions = [ 
            "kms:GenerateDataKey",
            "kms:Decrypt"
        ]
        condition {
            test     = "StringEquals"
            variable = "kms:ViaService"
            values   = [ "s3.${data.aws_region.current.name}.amazonaws.com" ]
        }
        condition {
            test     = "StringLike"
            variable = "kms:EncryptionContext:aws:s3:arn"
            values   = [ "${aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn}/*" ]
        }
        resources = [ "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*" ]
    }

    statement {
        effect = "Allow"
        actions = [ 
            "kms:GenerateDataKey",
            "kms:Decrypt"
        ]
        condition {
            test     = "StringEquals"
            variable = "kms:ViaService"
            values   = [ "kinesis.${data.aws_region.current.name}.amazonaws.com" ]
        }
        condition {
            test     = "StringLike"
            variable = "kms:EncryptionContext:aws:kinesis:arn"
            values   = [ aws_kinesis_stream.os_kinesis_data_stream.arn ]
        }
        resources = [ "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*" ]
    }
}

resource "aws_iam_policy" "os_kinesis_delivery_stream_role_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchKinesisDeliveryStreamRolePolicy"
    policy = data.aws_iam_policy_document.os_kinesis_delivery_stream_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "os_kinesis_delivery_stream_role_attachment" {
    role       = aws_iam_role.os_kinesis_delivery_stream_role.name
    policy_arn = aws_iam_policy.os_kinesis_delivery_stream_role_policy.arn
} 

resource "aws_kinesis_firehose_delivery_stream" "os_kinesis_delivery_stream" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchFirehose"
    destination = "elasticsearch"
    server_side_encryption {
        enabled  = true
        key_type = "AWS_OWNED_CMK"
        # key_type = "CUSTOMER_MANAGED_CMK"
        # kms_arn = ...
    }
    elasticsearch_configuration {
        cloudwatch_logging_options {
            enabled         = true
            log_group_name  = aws_cloudwatch_log_group.os_kinesis_delivery_stream_log_group.name
            log_stream_name = aws_cloudwatch_log_stream.os_kinesis_delivery_stream_os_delivery_log_stream.name
        }
        domain_arn = aws_elasticsearch_domain.opensearch.arn
        index_name = var.os_index_name
        index_rotation_period = "OneDay"
        role_arn = aws_iam_role.os_kinesis_delivery_stream_role.arn
        s3_backup_mode = "AllDocuments"
    }
    s3_configuration {
        bucket_arn = aws_s3_bucket.os_kinesis_delivery_stream_backup_bucket.arn
        cloudwatch_logging_options {
            enabled         = true
            log_group_name  = aws_cloudwatch_log_group.os_kinesis_delivery_stream_log_group.name
            log_stream_name = aws_cloudwatch_log_stream.os_kinesis_delivery_stream_s3_delivery_log_stream.name
        }
        compression_format = "GZIP"
        role_arn = aws_iam_role.os_kinesis_delivery_stream_role.arn
    }
}

# ##################################################################################################
# Resources for Log Data Transformation
# ##################################################################################################

module "log_data_transformation" { 
    source = "git::https://github.com/katjes733/log-data-transformation-module.git//src/terraform"

    resource_prefix             = var.resource_prefix
    kinesis_delivery_stream_arn = aws_kinesis_firehose_delivery_stream.os_kinesis_delivery_stream.arn
    kinesis_data_stream_arn     = aws_kinesis_stream.os_kinesis_data_stream.arn
}
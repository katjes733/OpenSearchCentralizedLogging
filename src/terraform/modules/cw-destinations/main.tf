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
# Resources to handle initial log data ingestion.
# Utilizes CloudWatch Destinations in all regions for all specified spoke accounts which forward
# all events to a Kinesis Data Stream.
# ##################################################################################################

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.13.0"
            configuration_aliases = [ 
                aws.ap-northeast-1, 
                aws.ap-northeast-2,
                aws.ap-northeast-3,
                aws.ap-south-1,
                aws.ap-southeast-1,
                aws.ap-southeast-2,
                aws.ca-central-1,
                aws.eu-central-1,
                aws.eu-north-1,
                aws.eu-west-1,
                aws.eu-west-2,
                aws.eu-west-3,
                aws.sa-east-1,
                aws.us-east-1,
                aws.us-east-2,
                aws.us-west-1,
                aws.us-west-2
            ]
        }
    }

    required_version = ">= 0.14.9"
}

# ##################################################################################################
# Constants
# ##################################################################################################

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

resource "random_string" "unique_id" {
    count   = var.resource_prefix == "" ? 1 : 0
    length  = 8
    special = false
    upper   = false
}

locals {
    regions = var.spoke_regions == "" ? tolist(["all"]) : split(",", var.spoke_regions)
}

# ##################################################################################################
# Resources
# ##################################################################################################

resource "aws_kinesis_stream" "kinesis_data_stream" {
    name             = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }KinesisDataStream"
    shard_count      = 1
    retention_period = 24
    encryption_type  = "KMS"
    kms_key_id       = "alias/aws/kinesis"
}

resource "aws_iam_role" "cw_destination_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}CloudWatchDestinationRole" : null    
    assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role_policy_document.json
}

data "aws_iam_policy_document" "cw_destination_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "kinesis:PutRecord" ]
        resources = [ aws_kinesis_stream.kinesis_data_stream.arn ]
    }
}

resource "aws_iam_policy" "cw_destination_role_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }CloudWatchDestinationRolePolicy"
    policy = data.aws_iam_policy_document.cw_destination_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "cw_destination_role_attachment" {
    role       = aws_iam_role.cw_destination_role.name
    policy_arn = aws_iam_policy.cw_destination_role_policy.arn
}

module "ap-northeast-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-northeast-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]

    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-northeast-1
    }
}

module "ap-northeast-2_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-northeast-2")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-northeast-2
    }
}

module "ap-northeast-3_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-northeast-3")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-northeast-3
    }
}

module "ap-south-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-south-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-south-1
    }
}

module "ap-southeast-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-southeast-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-southeast-1
    }
}

module "ap-southeast-2_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ap-southeast-2")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ap-southeast-2
    }
}

module "ca-central-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "ca-central-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.ca-central-1
    }
}

module "eu-central-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "eu-central-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.eu-central-1
    }
}

module "eu-north-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "eu-north-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.eu-north-1
    }
}

module "eu-west-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "eu-west-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.eu-west-1
    }
}

module "eu-west-2_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "eu-west-2")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.eu-west-2
    }
}

module "eu-west-3_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "eu-west-3")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.eu-west-3
    }
}

module "sa-east-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "sa-east-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.sa-east-1
    }
}

module "us-east-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "us-east-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.us-east-1
    }
}

module "us-east-2_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "us-east-2")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.us-east-2
    }
}

module "us-west-1_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "us-west-1")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.us-west-1
    }
}

module "us-west-2_cw_destination" {
    count = (contains(local.regions, "all") || contains(local.regions, "us-west-2")) ? 1 : 0
    depends_on = [
        aws_iam_role_policy_attachment.cw_destination_role_attachment
    ]
    source = "git::https://github.com/katjes733/cloudwatch-destination-module.git//src/terraform"

    resource_prefix         = var.resource_prefix
    spoke_accounts          = var.spoke_accounts
    destination_name        = var.destination_name
    kinesis_stream_arn      = aws_kinesis_stream.kinesis_data_stream.arn
    cw_destination_role_arn = aws_iam_role.cw_destination_role.arn

    providers = {
        aws = aws.us-west-2
    }
}

# ##################################################################################################
# Outputs
# ##################################################################################################

output "kinesis_data_stream_arn" {
    value       = aws_kinesis_stream.kinesis_data_stream.arn
    description = "The ARN of the Kinesis Data Stream"
}
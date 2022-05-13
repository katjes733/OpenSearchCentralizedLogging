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
# Resources to handle transformation of log data received by the Kinesis Data Stream.
# Triggered by Kinesis Data Stream receipt and executed by Lambda function.
# ##################################################################################################

resource "aws_iam_role" "os_log_data_transformer_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchLogDataTransformerLambdaRole" : null    
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "os_log_data_transformer_role_attachment_basic" {
    role       = aws_iam_role.os_log_data_transformer_role.name
    policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

    statement {
        effect = "Allow"
        actions = [
            "firehose:PutRecordBatch"
        ]
        resources = [ aws_kinesis_firehose_delivery_stream.os_kinesis_delivery_stream.arn ]
    }
}

resource "aws_iam_policy" "os_log_data_transformer_role_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchLogDataTransformerLambdaRolePolicy"
    policy = data.aws_iam_policy_document.os_log_data_transformer_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "os_log_data_transformer_role_attachment_main" {
    role       = aws_iam_role.os_log_data_transformer_role.name
    policy_arn = aws_iam_policy.os_log_data_transformer_role_policy.arn
}

locals {
    os_kinesis_log_data_transformer_lambda_function_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchKinesisLogDataTransformer"
}

resource "aws_cloudwatch_log_group" "os_kinesis_log_data_transformer_log_group" {
    name = "/aws/lambda/${local.os_kinesis_log_data_transformer_lambda_function_name}"
    retention_in_days = 7
    # kms_key_id = ...
}

data "archive_file" "log_data_transformer" {
    type = "zip"
    source_file = "${path.module}/python/log_data_transformer.py"
    output_path = "${path.module}/.package/log_data_transformer.zip"
}

resource "aws_lambda_function" "os_kinesis_log_data_transformer" {
    depends_on = [
        aws_cloudwatch_log_group.os_kinesis_log_data_transformer_log_group,
        aws_iam_role_policy_attachment.os_log_data_transformer_role_attachment_basic,
        aws_iam_role_policy_attachment.os_log_data_transformer_role_attachment_main
    ]
    function_name = "${local.os_kinesis_log_data_transformer_lambda_function_name}"
    architectures = local.is_arm_supported_region ? ["arm64"] : ["x86_64"]
    filename = "${path.module}/.package/log_data_transformer.zip"
    source_code_hash = data.archive_file.log_data_transformer.output_base64sha256
    handler = "log_data_transformer.lambda_handler"
    runtime = "python3.9"
    memory_size = 128
    timeout = 300
    role = aws_iam_role.os_log_data_transformer_role.arn
    environment {
      variables = {
        "LOG_LEVEL" = "info",
        "DATA_STREAM_NAME" = aws_kinesis_firehose_delivery_stream.os_kinesis_delivery_stream.name
      }
    }
}

resource "aws_lambda_event_source_mapping" "os_kinesis_log_data_transformer_event_source" {
    event_source_arn  = aws_kinesis_stream.os_kinesis_data_stream.arn
    function_name     = aws_lambda_function.os_kinesis_log_data_transformer.arn
    batch_size        = 100
    starting_position = "TRIM_HORIZON"
}
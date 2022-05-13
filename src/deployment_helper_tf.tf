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
# Generic resources for the lambda function Deployment Helper for Terraform.
# ##################################################################################################

resource "aws_iam_role" "deployment_helper_tf_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}DeploymentHelperTerraformLambdaRole" : null    
    assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "deployment_helper_tf_role_attachment_basic" {
    role       = aws_iam_role.deployment_helper_tf_role.name
    policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "deployment_helper_tf_role_policy_document_main" {
    statement {
        effect = "Allow"
        actions = [
            "ec2:DescribeRegions",
            "logs:PutDestination",
            "logs:DeleteDestination",
            "logs:PutDestinationPolicy",
            "logs:DescribeDestinations"
        ]
        resources = [ "*" ]
    }
}

resource "aws_iam_policy" "deployment_helper_tf_role_policy_main" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }DeploymentHelperTerraformMainRolePolicy"
    policy = data.aws_iam_policy_document.deployment_helper_tf_role_policy_document_main.json
}

resource "aws_iam_role_policy_attachment" "deployment_helper_tf_role_attachment_main" {
    role       = aws_iam_role.deployment_helper_tf_role.name
    policy_arn = aws_iam_policy.deployment_helper_tf_role_policy_main.arn
}

locals {
    deployment_helper_tf_lambda_function_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }DeploymentHelperTerraform"
}

resource "aws_cloudwatch_log_group" "deployment_helper_tf_log_group" {
    name = "/aws/lambda/${local.deployment_helper_tf_lambda_function_name}"
    retention_in_days = 7
    # kms_key_id = ...
}

data "archive_file" "deployment_helper_tf" {
    type = "zip"
    source_file = "${path.module}/python/deployment_helper_tf.py"
    output_path = "${path.module}/.package/deployment_helper_tf.zip"
}

resource "aws_lambda_function" "deployment_helper_tf" {
    depends_on = [
        aws_cloudwatch_log_group.deployment_helper_tf_log_group,
        aws_iam_role_policy_attachment.deployment_helper_tf_role_attachment_basic,
        aws_iam_role_policy_attachment.deployment_helper_tf_role_attachment_main
    ]
    function_name = "${local.deployment_helper_tf_lambda_function_name}"
    architectures = local.is_arm_supported_region ? ["arm64"] : ["x86_64"]
    filename = "${path.module}/.package/deployment_helper_tf.zip"
    source_code_hash = data.archive_file.deployment_helper_tf.output_base64sha256
    handler = "deployment_helper_tf.lambda_handler"
    runtime = "python3.9"
    memory_size = 128
    timeout = 300
    role = aws_iam_role.deployment_helper_tf_role.arn
    environment {
      variables = {
        "LOG_LEVEL" = "info"
      }
    }
}
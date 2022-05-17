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

resource "aws_kinesis_stream" "os_kinesis_data_stream" {
    name             = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchKinesisDataStream"
    shard_count      = 1
    retention_period = 24
    encryption_type  = "KMS"
    kms_key_id       = "alias/aws/kinesis"
}

resource "aws_iam_role" "os_cw_destination_role" {
    name = var.resource_prefix != "" ? "${var.resource_prefix}OpenSearchCloudWatchDestinationRole" : null    
    assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role_policy_document.json
}

data "aws_iam_policy_document" "os_cw_destination_role_policy_document" {
    statement {
        effect = "Allow"
        actions = [ "kinesis:PutRecord" ]
        resources = [ aws_kinesis_stream.os_kinesis_data_stream.arn ]
    }
}

resource "aws_iam_policy" "os_cw_destination_role_policy" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCloudWatchDestinationRolePolicy"
    policy = data.aws_iam_policy_document.os_cw_destination_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "os_cw_destination_role_attachment" {
    role       = aws_iam_role.os_cw_destination_role.name
    policy_arn = aws_iam_policy.os_cw_destination_role_policy.arn
}

# ##################################################################################################
# Special Policy required for Deployment Helper Terraform 
# ##################################################################################################
data "aws_iam_policy_document" "deployment_helper_tf_role_policy_document_add" {
    statement {
        effect = "Allow"
        actions = [ "iam:PassRole" ]
        resources = [ aws_iam_role.os_cw_destination_role.arn ]
    }
}

resource "aws_iam_policy" "deployment_helper_tf_role_policy_add" {
    name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }DeploymentHelperTerraformAddRolePolicy"
    policy = data.aws_iam_policy_document.deployment_helper_tf_role_policy_document_add.json
}

resource "aws_iam_role_policy_attachment" "deployment_helper_tf_role_attachment_add" {
    role       = aws_iam_role.deployment_helper_tf_role.name
    policy_arn = aws_iam_policy.deployment_helper_tf_role_policy_add.arn
}

# ##################################################################################################
# Deletion of CloudWatch Destinations
# ##################################################################################################
resource "null_resource" "os_cw_destinations_deletion" {
    depends_on = [
        aws_lambda_function.deployment_helper_tf,
        aws_iam_role_policy_attachment.deployment_helper_tf_role_attachment_add
    ]
    triggers = { 
        region           = data.aws_region.current.name
        function_name    = aws_lambda_function.deployment_helper_tf.function_name 
        service_token    = aws_lambda_function.deployment_helper_tf.arn
        regions          = var.spoke_regions
        destination_name = var.destination_name
        role_arn         = aws_iam_role.os_cw_destination_role.arn
        data_stream_arn  = aws_kinesis_stream.os_kinesis_data_stream.arn
        spoke_accounts   = var.spoke_accounts != "" ? var.spoke_accounts : data.aws_caller_identity.current.account_id

    }
    provisioner "local-exec" {
        when    = destroy
        command = replace(<<-COMMAND
            aws lambda invoke \
            --cli-binary-format raw-in-base64-out \
            --log-type Tail \
            --region ${self.triggers.region} \
            --function-name ${self.triggers.function_name} \
            --payload {
                "ResourceType":"Custom::CloudWatchDestination",
                "RequestType":"Delete",
                "ResourceProperties":{
                    "ServiceToken":"${self.triggers.service_token}",
                    "Regions":"${self.triggers.regions}",
                    "DestinationName":"${self.triggers.destination_name}",
                    "RoleArn":"${self.triggers.role_arn}",
                    "DataStreamArn":"${self.triggers.data_stream_arn}",
                    "SpokeAccounts":"${self.triggers.spoke_accounts}"
                }
            } \
            response.json
        COMMAND
        , "/(\\\\)*\\r\\n\\s*/", "")
    }
}

# ##################################################################################################
# Creation of CloudWatch Destinations
# Depends on null_resource.os_cw_destinations_deletion to ensure execution on delete BEFORE
# ##################################################################################################
data "aws_lambda_invocation" "os_cw_destinations_creation" {
    depends_on = [
        aws_lambda_function.deployment_helper_tf,
        aws_iam_role_policy_attachment.deployment_helper_tf_role_attachment_add,
        null_resource.os_cw_destinations_deletion
    ]
    function_name = aws_lambda_function.deployment_helper_tf.function_name
    input = jsonencode({
        "ResourceType" = "Custom::CloudWatchDestination",
        "RequestType"  = "Create",
        "ResourceProperties": {
            "Regions"           = var.spoke_regions,
            "DestinationName"   = var.destination_name,
            "RoleArn"           = aws_iam_role.os_cw_destination_role.arn,
            "DataStreamArn"     = aws_kinesis_stream.os_kinesis_data_stream.arn
            "SpokeAccounts"     = var.spoke_accounts != "" ? var.spoke_accounts : data.aws_caller_identity.current.account_id
        }
    })
}
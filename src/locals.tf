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


locals {
    is_arm_supported_region = contains(["us-east-1", "us-west-2", "eu-central-1", "eu-west-1", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"], data.aws_region.current.name)
    os_cognito_user_pool_pre_signup_lambda_function_name = "%{ if var.resource_prefix != "" }${var.resource_prefix}%{ else }${random_string.unique_id}-%{ endif }OpenSearchCognitoUserPoolPreSignUp"
}

locals {
    os_sizing_node_count = {
        XS = 1
        S  = 2
        M  = 3
        L  = 4
    }
    os_sizing_master_count = {
        XS = 0
        S  = 1
        M  = 2
        L  = 3
    }
    os_sizing_master_size = {
        XS = "NA"
        S  = "c6g.large.elasticsearch"
        M  = "c6g.large.elasticsearch"
        L  = "c6g.large.search"
    }
    os_sizing_instance_size = {
        XS = "t3.small.elasticsearch"
        S  = "r6g.large.elasticsearch"
        M  = "r6g.2xlarge.elasticsearch"
        L  = "r6g.4xlarge.elasticsearch"
    }
    os_sizing_volume_size = {
        XS = 10
        S  = 20
        M  = 40
        L  = 80
    }
}

locals {
    use_master_node     = lookup(local.os_sizing_master_count, var.os_size) != 0
}
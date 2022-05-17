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

aws_region = "us-east-1"

tag_owner = "martin.macecek@rearc.io"

tag_type = "Internal"

tag_usage = "Playground"

resource_prefix = "mac-re-"

os_domain_name = "mac-re-cwl"

os_size = "XS"

os_multi_az = false

os_engine_version = "1.2"

os_index_name = "cwl"

os_custom_dashboards_domain = ""

os_admin_email = "martin.macecek@rearc.io"

os_dashboards_allowed_email_signup_regex = "^.*(@rearc.io)$"

os_dashboards_auto_confirm_user = false

os_dashboards_allowed_cidrs = ""

spoke_regions = ""

spoke_accounts = ""

destination_name = "Central-CloudWatch-Logging"
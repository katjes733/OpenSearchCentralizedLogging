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

variable "aws_region" {
    description = "The AWS region for deployment."
    type        = string
    default     = "us-east-1"

    validation {
        condition     = can(regex("^[a-z]{2}-(gov-){0,1}(north|northeast|east|southeast|south|southwest|west|northwest|central)-[1-9]{1}$", var.aws_region))
        error_message = "Must be a valid AWS region."
    }
}

variable "resource_prefix" {
    description = "The prefix for all resources. If empty, uniquenss of resource names is ensured."
    type        = string
    default     = "mac-"

    validation {
        condition     = can(regex("^$|^[a-z0-9-]{0,7}$", var.resource_prefix))
        error_message = "The resource_prefix must be empty or not be longer that 7 characters containing only the following characters: a-z0-9- ."
    }
}

variable "os_domain_name" {
    description = "Name of the OpenSearch Domain. Also used as subdomain Custom OpenSearch Dashboards."
    type        = string

    validation {
        condition     = can(regex("^[a-z0-9-]{3,28}$", var.os_domain_name))
        error_message = "The OpenSearch Domain must be between 3 and 28 characters (a-z0-9-)."
    }
}

variable "os_engine_version" {
    description = "The name of OpenSearch engine version."
    type        = string
    default     = "1.2"

    validation {
        condition     = can(regex("^\\d+.\\d+$", var.os_engine_version))
        error_message = "The OpenSearch Engine version must be a valid version number (e.g. 1.2)."
    }
}

variable "os_custom_dashboards_domain" {
    description = "Domain for the Custom OpenSearch Dashboards."
    type        = string

    validation {
        condition     = can(regex("^$|([\\w-]+\\.)+[\\w-]+$", var.os_custom_dashboards_domain))
        error_message = "The OpenSearch Domain must be a valid domain."
    }
}

variable "os_admin_email" {
    description = "The email address of the admin account"
    type        = string

    validation {
        condition     = can(regex("^[\\w\\.]+\\@[\\w]+\\.[a-z]+$", var.os_admin_email))
        error_message = "The OpenSearch Domain must not be empty."
    }
}

variable "os_dashboards_allowed_email_signup_regex" {
    description = "Restrict sign up only to emails matching this regular expression (leave empty to allow all - not recommended)"
    type        = string
    default     = ""
}

variable "os_dashboards_auto_confirm_user" {
    description = "Whether or not users signing up DO NOT have to confirm their email with a security code (highly recommended to leave at false)"
    type        = bool
    default     = false
}

variable "os_dashboards_allowed_cidrs" {
    description = "The allowed CIDRs to access the OpenSearch Dashboards"
    type        = string
    default     = ""

    validation {
        condition     = can(regex("^$|^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/([0-9]|[1-2][0-9]|3[0-2]))(,(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/([0-9]|[1-2][0-9]|3[0-2])))*$", var.os_dashboards_allowed_cidrs))
        error_message = "Must be a valid list of comma separated CIDRs."
    }
}
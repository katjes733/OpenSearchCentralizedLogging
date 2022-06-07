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

variable "resource_prefix" {
    description = "The prefix for all resources. If empty, uniquness of resource names is ensured."
    type        = string
    default     = "mac-"

    validation {
        condition     = can(regex("^$|^[a-z0-9-]{0,7}$", var.resource_prefix))
        error_message = "The resource_prefix must be empty or not be longer that 7 characters containing only the following characters: a-z0-9- ."
    }
}

variable "allowed_email_signup_regex" {
    description = "Restrict sign up only to emails matching this regular expression (leave empty to allow all - not recommended)"
    type        = string
    default     = ""
}

variable "auto_confirm_user" {
    description = "Whether or not users signing up DO NOT have to confirm their email with a security code (highly recommended to leave at false)"
    type        = bool
    default     = false
}

variable "domain_name" {
    description = "Name of the Domain."
    type        = string

    validation {
        condition     = can(regex("^[a-z0-9-]{3,28}$", var.domain_name))
        error_message = "The Domain must be between 3 and 28 characters (a-z0-9-)."
    }
}

variable "admin_email" {
    description = "The email address of the admin account"
    type        = string

    validation {
        condition     = can(regex("^[\\w\\.]+\\@[\\w]+\\.[a-z]+$", var.admin_email))
        error_message = "The Admin Email must not be empty."
    }
}
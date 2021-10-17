# OpenSearchCentralizedLogging
AWS OpenSearch based All-In-One Centralized Logging solution with easy integration into CloudWatch

## Feature overview
1. Solution allows for white listing of IP addresses in CIDR notation (all others are blocked) to access the Dashboards. Whitelisting kicks in after authentication of a user. By default all IPs are allowed.
1. Solution allows to specify regex to match emails allowed to sign up. Non matching are not allowed to sign up.

## Template Parameters
| Parameter | Description | Mandatory | Allowed values |
| --- | --- | --- | --- |
| OpenSearch Name | Name of the OpenSearch Domain. Also used as subdomain Custom OpenSearch Dashboards. | yes | any valid string |
| Custom Domain for OpenSearch Dashboards | Domain for the Custom OpenSearch Dashboards. | yes | any valid string matching the pattern |
| Administrator Email | The email address of the admin account | yes | any valid string matching the pattern |
| OpenSearch Index Name | The name of the index in OpenSearch | yes | any valid string matching the pattern |
| OpenSearch Cluster Size | OpenSearch cluster size; XS (1 data node), S (4 data nodes), M (6 data nodes), L (6 data nodes) | no | XS, S, M or L |
| OpenSearch Multi AZ Configuration | Whether or not to use Multi AZ | no | false or true |
| OpenSearch Dashboards Allowed CIDRs | The allowed CIDRs to access the OpenSearch Dashboards | no | any valid string matching the pattern |
| OpenSearch Dashboards Allowed Email Sign Up Regex | Restrict sign up only to emails matching this regular expression (leave empty to allow all - not recommended) | no | any valid string matching the pattern |
| OpenSearch Dashboards Auto Confirm User | Whether or not users signing up DO NOT have to confirm their email with a security code (highly recommended to leave at false) | no | false or true |
| Log Delivery Regions | The comma separated list of regions to be supported. Leave empty for all regions. | no | any valid string matching the pattern |
| Log Delivery Accounts | The comma separated list of accounts that may deliver logs. Leave empty for current account only. | no | any valid string matching the pattern |
| Log Delivery Destination Name | The name of the destination for each region | no | any valid string matching the pattern |
| Resource Prefix | The prefix for all resources. If empty, auto generated by AWS including the name of the stack. | no | any valid string matching the pattern |
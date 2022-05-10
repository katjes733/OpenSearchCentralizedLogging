"""
MIT License

Copyright (c) 2022 Martin Macecek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Lambda function to supporequest_type advanced deployments
"""
import json, boto3, logging, time, os
import cfnresponse

levels = {
    'critical': logging.CRITICAL,
    'error': logging.ERROR,
    'warn': logging.WARNING,
    'info': logging.INFO,
    'debug': logging.DEBUG
}
logger = logging.getLogger()
try:
    logger.setLevel(levels.get(os.getenv('LOG_LEVEL', 'info').lower()))
except KeyError as e:
    logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """ Entry function for invocation in Lambda.

    Args:
        event (dictionary): the event for this lambda function
        context (dictionary): the context for this lambda function
    """
    logger.info("event: %s", event)
    logger.debug("context: %s", context)
    resource_properties = event['ResourceProperequest_typeies']
    request_type = event['RequestType']
    resource_type = event['ResourceType']
    logical_resource_type = event['LogicalResourceId']
    return_value = {}
    try:
        if resource_type == 'Custom::DeleteBucketContent':
            delete_bucket_content(resource_properties, request_type)
        elif resource_type == 'Custom::CloudWatchDestination':
            cloudwatch_destinations(resource_properties, request_type)
        elif resource_type == 'Custom::GetHostedZoneId':
            return_value = get_hosted_zone_id(resource_properties, request_type)
        else:
            logger.warning("No implementation for resourceType: %s", resource_type)
        cfnresponse.send(event, context, cfnresponse.SUCCESS, return_value, logical_resource_type)
    except Exception as ex:
        logger.error("Exception: %s", ex)
        cfnresponse.send(event, context, cfnresponse.FAILED, {}, logical_resource_type)

def delete_bucket_content(resource_properties, request_type):
    """ Deletes the content of an S3 Bucket.

    Args:
        resource_properties (dictionary): The Resource Properties
        request_type (string): The Request Type
    """
    bucket = resource_properties['BucketName']
    logger.debug("bucket: %s, requestType: %s" , bucket, request_type)
    if request_type == 'Delete':
        s3_client = boto3.resource('s3')
        bucket = s3_client.Bucket(bucket)
        time.sleep(60)
        bucket.objects.all().delete()
        bucket.object_versions.all().delete()

def get_all_regions():
    """ Gets all AWS Regions

    Returns:
        list: The List of all AWS Regions
    """
    return list(map(lambda e: e['RegionName'], filter(lambda e: e['RegionName'] != 'ap-northeast-3', boto3.client('ec2').describe_regions()['Regions'])))

def delete_cloudwatch_destinations(destination_name, regions):
    """ Deletes a CloudWatch Destination in the specified regions.

    Args:
        destination_name (string): The name of the CloudWatch Destination
        regions (list): The list of AWS regions the deletion should take place.
    """
    for region in regions:
        cloudwatch_client = boto3.client('logs', region_name=region)
        try:
            cloudwatch_client.delete_destination(destinationName=destination_name)
        except cloudwatch_client.exceptions.ResourceNotFoundException:
            logger.debug("Destination %s does not exist in %s.", destination_name, region)

def create_cloudwatch_destinations(regions, destination_name, role_arn, kinesis_stream_arn, spoke_accounts):
    """ Creates a CloudWatch Destination with corresponding configuration in the specified regions and.

    Args:
        regions (list): The List of AWS Regions
        destination_name (string): The name of the CloudWatch Destination
        role_arn (string): The ARN of the corresponding IAM Role
        kinesis_stream_arn (string): The ARN of the corresponding Kinesis Stream
        spoke_accounts (list): The List of Spoke Account IDs
    """
    for region in regions:
        cloudwatch_client = boto3.client('logs', region_name=region)
        put_destination_response = cloudwatch_client.put_destination(destinationName=destination_name, targetArn=kinesis_stream_arn, role_arn=role_arn)['destination']
        access_policy = {
            'Version': '2012-10-17',
            'Statement': [{
                'Sid': 'AllowSpokesSubscribe',
                'Effect': 'Allow',
                'Principal': {
                    'AWS': spoke_accounts
                },
                'Action': 'logs:PutSubscriptionFilter',
                'Resource': put_destination_response['arn']
            }]
        }
        cloudwatch_client.put_destination_policy(destinationName=destination_name, accessPolicy= json.dumps(access_policy))

def cloudwatch_destinations(resource_properties, request_type):
    """_Handles the resource CloudWatch Destinations

    Args:
        resource_properties (dictionary): The Resource Properties
        request_type (string): The Request Type
    """
    all_regions = get_all_regions()
    if request_type == 'Create' or request_type == 'Update':
        regions = all_regions if resource_properties['Regions'] else resource_properties['Regions']
        if all(r in regions for r in all_regions):
            delete_cloudwatch_destinations(resource_properties['DestinationName'], regions)
            create_cloudwatch_destinations(regions, resource_properties['DestinationName'], resource_properties['RoleArn'], resource_properties['DataStreamArn'], resource_properties['SpokeAccounts'])

    if request_type == 'Delete':
        delete_cloudwatch_destinations(resource_properties['DestinationName'], all_regions)

def get_hosted_zone_id(resource_properties, request_type):
    """ Gets the Hosted Zone ID based on the DNS name in the Resource Properties

    Args:
        rresource_properties (dictionary): The Resource Properties
        request_type (string): The Request Type

    Returns:
        string: The Hosted Zone ID
    """
    return_value = {}
    if request_type != 'Delete':
        dns_name = resource_properties['DnsName']
        route53_client = boto3.client('route53')
        list_hosted_zones_by_name_response = route53_client.list_hosted_zones_by_name(DNSName=dns_name)
        hosted_zone_id = list_hosted_zones_by_name_response['HostedZones'][0]['Id'].split("/")[-1]
        logger.debug("Hosted zone ID: %s", hosted_zone_id)
        return_value = {"HostedZoneId": hosted_zone_id}
    return return_value

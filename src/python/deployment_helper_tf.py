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
import json
import logging
import os
import re
import boto3

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

    Returns:
        dictionary: The Lists of ARNs for the created and deleted CloudWatch Destinations \
            for each invocation
    """
    logger.info("event: %s", event)
    logger.debug("context: %s", context)
    resource_properties = event['ResourceProperties']
    request_type = event['RequestType']
    resource_type = event['ResourceType']
    return_value = {}
    try:
        if resource_type == 'Custom::CloudWatchDestination':
            cloudwatch_destinations(resource_properties, request_type)
        else:
            logger.warning("No implementation for ResourceType: %s", resource_type)
    except Exception as ex:
        logger.error("Exception: %s", ex)

    logger.info("Outputs: %s", return_value)
    return return_value

def get_all_regions():
    """ Gets all AWS Regions

    Returns:
        list: The List of all AWS Regions
    """
    return list(map(lambda e: e['RegionName'], \
        filter(lambda e: e['RegionName'] != 'ap-northeast-3', \
        boto3.client('ec2').describe_regions()['Regions'])))

def delete_cloudwatch_destinations(destination_name, regions):
    """ Deletes a CloudWatch Destination in the specified regions.

    Args:
        destination_name (string): The name of the CloudWatch Destination
        regions (list): The list of AWS regions the deletion should take place.

    Returns:
        list: The List of ARNs for the deleted CloudWatch Destinations
    """
    return_value = []
    account_id = ""
    for region in regions:
        cloudwatch_client = boto3.client('logs', region_name=region)
        if not account_id:
            describe_destinations_response = \
                cloudwatch_client.describe_destinations(DestinationNamePrefix=destination_name)
            if describe_destinations_response['destinations']:
                account_id = re.search(r'\d{12}', \
                    describe_destinations_response['destinations'][0]['arn']).group()
            logger.debug("Account ID: %s", account_id)
        try:
            cloudwatch_client.delete_destination(destinationName=destination_name)
            deleted_cloudwatch_destination_arn = \
                f"arn:aws:logs:{region}:{account_id}:destination:{destination_name}"
            logger.debug("Deleted CloudWatch Destination ARN: %s", \
                deleted_cloudwatch_destination_arn)
            return_value.append(deleted_cloudwatch_destination_arn)
        except cloudwatch_client.exceptions.ResourceNotFoundException:
            logger.debug("Destination %s does not exist in %s.", destination_name, region)
    logger.info("Deleted CloudWatch Destinations: %s", return_value)
    return return_value

def create_cloudwatch_destinations(regions, destination_name, role_arn, \
    kinesis_stream_arn, spoke_accounts):
    """ Creates a CloudWatch Destination with corresponding configuration in the \
        specified regions and accounts.

    Args:
        regions (list): The List of AWS Regions
        destination_name (string): The name of the CloudWatch Destination
        role_arn (string): The ARN of the corresponding IAM Role
        kinesis_stream_arn (string): The ARN of the corresponding Kinesis Stream
        spoke_accounts (list): The List of Spoke Account IDs

    Returns:
        list: The List of ARNs for the created CloudWatch Destinations
    """
    return_value = []
    for region in regions:
        cloudwatch_client = boto3.client('logs', region_name=region)
        put_destination_response = cloudwatch_client.put_destination( \
            destinationName=destination_name, targetArn=kinesis_stream_arn, \
                roleArn=role_arn)['destination']
        logger.debug("Created CloudWatch Destination ARN: %s", \
            put_destination_response['arn'])
        return_value.append(put_destination_response['arn'])
        access_policy = {
            'Version': '2012-10-17',
            'Statement': [{
                'Sid': 'AllowSpokesSubscribe',
                'Effect': 'Allow',
                'Principal': {
                    'AWS': spoke_accounts.split(',')
                },
                'Action': 'logs:PutSubscriptionFilter',
                'Resource': put_destination_response['arn']
            }]
        }
        cloudwatch_client.put_destination_policy( \
            destinationName=destination_name, accessPolicy=json.dumps(access_policy))
    logger.info("Created CloudWatch Destinations: %s", return_value)
    return return_value

def cloudwatch_destinations(resource_properties, request_type):
    """_Handles the resource CloudWatch Destinations

    Args:
        resource_properties (dictionary): The Resource Properties
        request_type (string): The Request Type

    Returns:
        dictionary: The Lists of ARNs for the created and deleted CloudWatch Destinations \
            for each invocation
    """
    return_value = {}
    return_value['CreatedCwDestinations'] = []
    all_regions = get_all_regions()
    if request_type == 'Create' or request_type == 'Update':
        regions = all_regions if not resource_properties['Regions'] \
            else resource_properties['Regions'].split(',')
        logger.info("Regions: %s", regions)
        if all(region in all_regions for region in regions):
            return_value['DeletedCwDestinations'] = delete_cloudwatch_destinations( \
                resource_properties['DestinationName'], all_regions)
            return_value['CreatedCwDestinations'] = create_cloudwatch_destinations(regions, \
                resource_properties['DestinationName'], \
                    resource_properties['RoleArn'], \
                        resource_properties['DataStreamArn'], \
                            resource_properties['SpokeAccounts'])

    if request_type == 'Delete':
        return_value['DeletedCwDestinations'] = delete_cloudwatch_destinations( \
            resource_properties['DestinationName'], all_regions)

    return return_value

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

Lambda function to transform log data for kinesis firehose
"""
from io import BytesIO
from datetime import datetime
import json
import logging
import base64
import gzip
import os
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

def transform_log_event(log_event, owner, log_group, log_stream):
    """ Transforms a single log event as needed for ingestion into OpenSearch

    Args:
        log_event (dictionary): The log event
        owner (string):  The Owner
        log_group (string): The name of the log group
        log_stream (string): The name of the log stream

    Returns:
        dictionary: The transofrmed log event
    """
    return_value = {}
    return_value['timestamp'] = datetime.fromtimestamp(log_event['timestamp']/1000.0).isoformat()
    return_value['id'] = log_event['id']
    return_value['type'] = "CloudWatchLogs"
    return_value['@message'] = log_event['message']
    return_value['@owner'] = owner
    return_value['@log_group'] = log_group
    return_value['@log_stream'] = log_stream
    return return_value

def create_records_from_log_events(log_events, owner, log_group, log_stream):
    """ Creates records based on the log event information

    Args:
        log_events (array): Array of log events
        owner (string):  The Owner
        log_group (string): The name of the log group
        log_stream (string): The name of the log stream

    Returns:
        array: Array of records based on the log event information
    """
    return_value = []
    for log_event in log_events:
        transformed_log_event = transform_log_event(log_event, owner, log_group, log_stream)
        data_bytes = json.dumps(transformed_log_event).encode("utf-8")
        return_value.append({"Data": data_bytes})
    return return_value

def put_records_to_firehose_stream(stream_name, records, client, attempts_made, max_attempts):
    """ Puts the records to the firehose stream

    Args:
        stream_name (string): The firehose stream name
        records (array): Array of records to put on firehose stream
        client (boto3.client): The AWS Client to use for the operation
        attempts_made (number): The number of attempts processed so far
        max_attempts (number): The max number of attempts

    Raises:
        RuntimeError: Only if there is an issue putting the records to the firehose
                        stream after a number of attempts
    """
    failed_records = []
    codes = []
    error_message = ''
    response = None
    try:
        response = client.put_record_batch(DeliveryStreamName=stream_name, Records=records)
    except Exception as ex:
        failed_records = records
        error_message = str(ex)

    if not failed_records and response and response['FailedPutCount'] > 0:
        for index, response in enumerate(response['RequestResponses']):
            if 'ErrorCode' not in response or not response['ErrorCode']:
                continue

            codes.append(response['ErrorCode'])
            failed_records.append(records[index])

        error_message = f"Individual error codes: {','.join(codes)}"

    if len(failed_records) > 0:
        if attempts_made + 1 < max_attempts:
            logger.warning("Some records failed while calling PutRecordBatch to Firehose stream, \
                retrying. %s", error_message)
            put_records_to_firehose_stream(stream_name, failed_records, \
                client, attempts_made + 1, max_attempts)
        else:
            message = f"Could not put records after {str(max_attempts)} attempts. {error_message}"
            logger.error(message)
            raise RuntimeError(message)

def process_records(records, client, stream_name):
    """ Processes the records

    Args:
        records (dictionary): The records from firehose
        client (boto3.client): The AWS Client to use for the operation
        stream_name (string): The name of the stream

    Returns:
        array: Array of processed records
    """
    return_value = []
    for record in records:
        data = base64.b64decode(record['kinesis']['data'])
        string_io_data = BytesIO(data)
        with gzip.GzipFile(fileobj=string_io_data, mode='r') as file:
            data = json.loads(file.read())

        logger.debug("Data: %s", data)
        if data['messageType'] == 'DATA_MESSAGE':
            firehose_records = create_records_from_log_events(data['log_events'], data['owner'], \
                data['log_group'], data['log_stream'])
            logger.debug("Firehose_records: %s", firehose_records)
            return_value.append(firehose_records)
            put_records_to_firehose_stream(stream_name, firehose_records, client, \
                attempts_made=0, max_attempts=20)

    return return_value

def lambda_handler(event, context):
    """ Entry function for invocation in Lambda.

    Args:
        event (dictionary): the event for this lambda function
        context (dictionary): the context for this lambda function
    """
    logger.info("Event: %s", event)
    logger.debug("Context: %s", context)
    logger.info("Start processing event records.")
    stream_name = os.environ['DATA_STREAM_NAME']
    client = boto3.client('firehose')
    records = process_records(event['Records'], client, stream_name)
    logger.info("Finished processing event records.")
    logger.debug("Records: %s", records)

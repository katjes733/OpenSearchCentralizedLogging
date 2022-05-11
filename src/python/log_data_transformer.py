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
import json, boto3, logging, base64, gzip, os
from io import BytesIO
from datetime import datetime

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

def transform_log_event(logEvent, owner, logGroup, logStream):
    return_value = {}
    return_value['timestamp'] = datetime.fromtimestamp(logEvent['timestamp']/1000.0).isoformat();
    return_value['id'] = logEvent['id'];
    return_value['type'] = "CloudWatchLogs";
    return_value['@message'] = logEvent['message']
    return_value['@owner'] = owner
    return_value['@log_group'] = logGroup
    return_value['@log_stream'] = logStream
    return return_value

def create_recordsfrom_log_events(logEvents, owner, logGroup, logStream):
    return_value = []
    for logEvent in logEvents:
        transformedLogEvent = transform_log_event(logEvent, owner, logGroup, logStream)
        dataBytes = json.dumps(transformedLogEvent).encode("utf-8")
        return_value.append({"Data": dataBytes})
    return return_value

def put_records_to_firehose_stream(stream_name, records, client, attempts_made, max_attempts):
    failed_records = []
    codes = []
    error_message = ''
    response = None
    try:
        response = client.put_record_batch(DeliveryStreamName=stream_name, Records=records)
    except Exception as e:
        failed_records = records
        error_message = str(e)

    if not failed_records and response and response['FailedPutCount'] > 0:
        for index, response in enumerate(response['RequestResponses']):            
            if 'ErrorCode' not in response or not response['ErrorCode']:
                continue

            codes.append(response['ErrorCode'])
            failed_records.append(records[index])

        error_message = f"Individual error codes: {','.join(codes)}"

    if len(failed_records) > 0:
        if attempts_made + 1 < max_attempts:
            logger.warn(f"Some records failed while calling PutRecordBatch to Firehose stream, retrying. {error_message}")
            put_records_to_firehose_stream(stream_name, failed_records, client, attempts_made + 1, max_attempts)
        else:
            message = f"Could not put records after {str(max_attempts)} attempts. {error_message}"
            logger.error(message)
            raise RuntimeError(message)

def process_records(records, client, stream_name):
    return_value = []
    for record in records:
        data = base64.b64decode(record['kinesis']['data'])
        string_io_data = BytesIO(data)
        with gzip.GzipFile(fileobj=string_io_data, mode='r') as f:
            data = json.loads(f.read())

        logger.debug(f"data: {data}")
        if data['messageType'] == 'DATA_MESSAGE':
            firehoseRecords = create_recordsfrom_log_events(data['logEvents'], data['owner'], data['logGroup'], data['logStream'])
            logger.debug(f"firehoseRecords: {firehoseRecords}")
            return_value.append(firehoseRecords)
            put_records_to_firehose_stream(stream_name, firehoseRecords, client, attempts_made=0, max_attempts=20)

    return return_value

def lambda_handler(event, context):
    logger.debug(f"Event: {event}")
    logger.info(f"Start processing event records.")
    stream_name = os.environ['DATA_STREAM_NAME']
    client = boto3.client('firehose')
    records = process_records(event['Records'], client, stream_name)
    logger.info(f"Finished processing event records.")    
    logger.debug(f"Records: {records}")
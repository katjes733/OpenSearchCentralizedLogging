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
import os, logging, re

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
        dictionary: The incoming event with autoConfirmUser set accordingly
    """
    logger.info("event: %s", event)
    logger.debug("context: %s", context)
    email = event['request']['userAttributes']['email']
    pattern = re.compile(f"{os.getenv('EMAIL_VALIDATION_REGEX', '^.*$')}")
    assert pattern.match(email), f": Email {email} is not allowed to sign up. Please contact the administrator if you believe you are getting this in error"
    event['response']['autoConfirmUser'] = os.getenv('AUTO_CONFIRM_USER', 'false').lower() == 'true'
    logger.debug("Outgoing event: %s", event)
    return event

#!/bin/bash
if [ ! -t 0 ]; then
    echo "Must be on a tty" >&2
    exit 255
fi

unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# Get caller identity and find username, exit if not found.
identity=$(aws sts get-caller-identity)
username=$(echo -- "$identity" | sed -n 's!.*"arn:aws:iam::.*:user/\(.*\)".*!\1!p')
if [ -z "$username" ]; then
    echo "Cannot identify username"
    exit 255
fi
echo "You're $username" >&2

# Use username to find MFA device, exit if not found.
mfa_devices=$(aws iam list-mfa-devices --user-name "$username")
serial_number=$(echo -- "$mfa_devices" | sed -n 's!.*"SerialNumber": "\(.*\)".*!\1!p')
if [ -z "$serial_number" ]; then
    echo "Cannot find any MFA device for $username"
    exit 255
fi
echo "Your MFA device is $serial_number" >&2

# If MFA code is passed as argument use that else ask user for MFA code.
if [ $# -eq 1 ]; then
    mfa_code=$1
else
    echo -n "Enter your 6 digits MFA code now: " >&2
    read mfa_code
fi

# Use MFA code to get tokens, exit if not found.
tokens=$(aws sts get-session-token --serial-number "$serial_number" --token-code $mfa_code)
access=$(echo -- "$tokens" | sed -n 's!.*"AccessKeyId": "\(.*\)".*!\1!p')
secret=$(echo -- "$tokens" | sed -n 's!.*"SecretAccessKey": "\(.*\)".*!\1!p')
session=$(echo -- "$tokens" | sed -n 's!.*"SessionToken": "\(.*\)".*!\1!p')
expire=$(echo -- "$tokens" | sed -n 's!.*"Expiration": "\(.*\)".*!\1!p')

if [ -z "$access" -o -z "$secret" -o -z "$session" ]; then
    echo "Unable to get temporary token for $username"
    exit 255
fi

export AWS_ACCESS_KEY_ID="$access"
export AWS_SECRET_ACCESS_KEY="$secret"
export AWS_SESSION_TOKEN="$session"
export AWS_SECURITY_TOKEN="$session"

echo "Session token valid until $expire" >&2

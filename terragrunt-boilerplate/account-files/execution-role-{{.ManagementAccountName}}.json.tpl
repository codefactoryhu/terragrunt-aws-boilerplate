{
  "account_id": "{{.ManagementAccountId}}",
  "name": "${env}",
  "policies": {
    "trust": {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": [
              "arn:aws:iam::${account_id}:root"
            ]
          },
          "Action": "sts:AssumeRole"
        }
      ]
    },
    "inline": {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "terragruntState",
          "Effect": "Allow",
          "Action": [
            "s3:*",
            "dynamodb:*",
            "iam:*"
          ],
          "Resource": [
            "*"
          ]
        }
      ]
    },
    "managed": []
  }
}

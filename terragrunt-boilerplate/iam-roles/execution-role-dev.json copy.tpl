{
  "account_id": "{{.DevelopmentAccountId}}",
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
        },
        {
          "Sid": "allowBudgets",
          "Effect": "Allow",
          "Action": [
            "budgets:*"
          ],
          "Resource": [
            "*"
          ]
        },
        {
          "Sid": "allowServices",
          "Effect": "Allow",
          "Action": [
            "logs:*",
            "lambda:*",
            "glue:*",
            "athena:*",
            "states:*",
            "apigateway:*",
            "secretsmanager:*",
            "cloudfront:*"
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

# README.md


# Tested on Linux CentOS 7 


# Dependencies:
1. pip / nc / curl / git
   * $ sudo yum install -y epel-release
   * $ sudo yum install -y python2-pip nc curl git

2. awscli
   * $ sudo pip install awscli


3. AWS IAM role attached to the nodes with the following policy attached, updated for your bucket name if you choose a s3 bucket other than s3-task-queue

```code
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::s3-task-queue",
                "arn:aws:s3:::s3-task-queue/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        }
    ]
}
```

4. If DATADOG_METRICS_ENABLED="true"
   * datadog agent must be installed 

5. Slack notifications require a Slack inbound webhook be configured
   * https://api.slack.com/incoming-webhooks

# s3-task-queue installon and configuration:

1. Checkout from get and move into the location of your choice, using clone then move to avoid run git command root.
   * git clone https://github.com/jassinpain/s3-task-queue.git
   * sudo mv s3-task-queue /opt/

2. Copy the s3-task-queue.task.conf.example and update variables:
   * cp /opt/s3-task-queue/etc/s3-task-queue.conf.example /opt/s3-task-queue/etc/s3-task-queue.conf
   * update /opt/s3-task-queue/etc/s3-task-queue.conf

3. Lock down the files:
   * chmod 600 /opt/s3-task-queue/etc/*
   * chmod 700 /opt/s3-task-queue/bin/*

4. Create Crontjob on all nodes, user must have access to all files from git repo:
   * crontab -e
     1. 35 * * * * /opt/s3-task-queue/bin/s3-task-queue.sh

# Known Issues:
* Server list management sucks, something like consul would allow discovery. Baring that we could make them register by dropping a file in the s3 bucket, then doing a list on the folder containing the node registery. Nodes would have to unregister on destroy on the file to s3 bucket method.
* Stale lock files may become a issue, investigate expiring lock file is pid in lock file is not active



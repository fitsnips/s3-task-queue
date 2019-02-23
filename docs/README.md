# README.md


# Tested on Linux CentOS 7 


# Dependencies:
* pip / nc / curl / git
- $ sudo yum install -y epel-release
- $ sudo yum install -y python2-pip nc curl git

* awscli
- $ sudo pip install awscli


* AWS IAM role attached to the nodes with the following policy attached, updated for your bucket name if you choose a s3 bucket other than mpartical-queue

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
                "arn:aws:s3:::s3-s3-task-queue/*"
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

* If DATADOG_METRICS_ENABLED="true"
- datadog agent should be installed 

# Node Configuration:

* Checkout from get and move into the location of your choice, using clone then move to avoid run git command root.
- git clone https://github.com/jassinpain/s3-task-queue.git
- sudo mv s3-task-queue /opt/



# copy the s3-task-queue.task.conf.example and update variables

# lock down the files, example
chmod 600 /opt/s3-task-queue/etc/*
chmod 700 /opt/s3-task-queue/bin/*

# Create Crontjob on all nodes, user must have access to all file from git repo
- crontab -e
- 35 * * * * /opt/s3-task-queue/bin/s3-task-queue.sh

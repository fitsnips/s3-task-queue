# README.md


# Tested on Linux CentOS 7 


# Dependencies:
* pip / nc / curl
- $ sudo yum install -y epel-release
- $ sudo yum install -y python2-pip nc curl

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

* Upload the tar file to your node and untar to directory of your choice, since we are not using git 
- example /opt/



# copy the s3-task-queue.task.conf.example and update variables

# lock down the files
sudo chmod 600 $CONFIG_DIR/CONFIG_FILE
sudo chmod 700 $CONFIG_DIR/bin/*
sudo chown -R <USER_TO_RUN_AS> $CONFIG_DIR

# Create Crontjob on all nodes
- crontab -e
- 35 * * * * /opt/s3-task-queue.task/bin/s3-task-queue.sh

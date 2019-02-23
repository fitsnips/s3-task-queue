#!/bin/bash
# mparicle_task.sh 
# Description:

# You may use methods/applications/languages of your choice, we just need to see the final product. If you have questions or need clarification on any of the items above, please let me know.
#########################
# Change Log:
# - 2018-02-21 <jmiller@vera.com>
# * created
#########################



BASE_DIR=/opt/s3-task-queue
CONFIG_DIR=$BASE_DIR/etc
BIN_DIR=$BASE_DIR/bin
LOCK_DIR=$BASE_DIR/lock
CONFIG_FILE=$CONFIG_DIR/s3-task-queue_task.conf


# would like to put this in config file but creates a circular problem
SYSLOGGER_CMD="logger -p user.notice -t s3-task-queue.task"


logStep() {
  MESSAGE=$*

  # 5. Syslog
  $SYSLOGGER_CMD $MESSAGE


  # 4. Slack
  getMessageLevel $MESSAGE
  MESSAGE_LEVEL="$?"

  if [ "$SLACK_WEBHOOK_URL" ]; then
    getMessageLevel ${SLACK_MESSAGE_LEVEL}
    SLACK_MESSAGE_LEVEL_NUMERIC="$?"

    if [ "${MESSAGE_LEVEL}" -ge "${SLACK_MESSAGE_LEVEL_NUMERIC}" ];then
      # 4. Slack
      # After looking at all the work it would take to handle the json in bash I decided to use the script from
      #  https://blog.sleeplessbeastie.eu/2017/06/12/how-to-post-message-from-command-line-into-slack/
      if [[ ${_MESSAGE} != *"SYSLOG"* ]]; then # avoids looping condition on slack error
        bash $BIN_DIR/slack_message.sh -h $SLACK_WEBHOOK_URL -c ${SLACK_CHANNEL} -u ${SLACK_POSTER} -i {SLACK_ICON} -m "$HOSTNAME $MESSAGE" \
          || logStep "SYSLOG: unable to post to slack channel ${SLACK_CHANNEL}"
      fi
    fi
  fi

 

  # 6 Datadog
  if [ "${DATADOG_METRICS_ENABLED}" != "false" ]; then
    # metric.name:value|type|@sample_rate|#tag1:value,tag2
    if [ "${MESSAGE}" = "NOTICE: Starting $TASK_FILE run" ]; then
      echo -n "s3-task-queue.task.started:1|c"|nc -4u -w1 localhost 8125
    elif [ "${MESSAGE}" = "NOTICE: Completed $TASK_FILE run"  ]; then
      echo -n "s3-task-queue.task.completed:1|c"|nc -4u -w1 localhost 8125
    elif [[ "${MESSAGE}" == "INFO: Runtime Seconds -"*  ]]; then
       local SECONDS=`echo ${MESSAGE}| cut -f2 -d"-"| sed -e 's/^[[:space:]]*//'` 
       echo -n "s3-task-queue.task.run_time:$SECONDS|h"|nc -4u -w1 localhost 8125
    fi
  fi

  # Exit on all crits
  if [[ ${MESSAGE} == *"FATAL"* ]]; then
    echo ${MESSAGE}
    exit 1
  fi
}



checkLock() {
  if [ -f "$LOCK_DIR/lockfile" ]; then
    logStep "FATAL: $LOCK_DIR/lockfile already exist exiting"
  fi
}

createLock() {
  if [ ! -d "$LOCK_DIR" ]; then
    mkdir -p $LOCK_DIR
  fi

  echo $$ > $LOCK_DIR/lockfile || logStep "FATAL: unable to create lockfile $LOCK_DIR/lockfile"

}

removeLock() {
  rm -f $LOCK_DIR/lockfile || logStep "FATAL: unable to remove lockfile $LOCK_DIR/lockfile"
}

verifyS3Access() {
  # can we list the bucket contents?
  aws s3 ls s3://$S3_BUCKET || logStep "FATAL: unable to read contents of s3://$S3_BUCKET"
}

fetchS3NodeFile() {
  # not sure lock dir is best place to put the status file, seems better then /tmp
  # we are suppresing output since we are OK with the file not existing
  aws s3 cp s3://$S3_BUCKET/$S3_NODE_FILE $LOCK_DIR/$S3_NODE_FILE --quiet || logStep "WARN: possible first run, unable to access s3://$S3_BUCKET/$S3_NODE_FILE" 
}

putS3NodeFile() {
  aws s3 cp $LOCK_DIR/$S3_NODE_FILE s3://$S3_BUCKET/$S3_NODE_FILE --quiet  || logStep "FATAL: unable to write object to s3://$S3_BUCKET/$S3_NODE_FILE"

}

getNextNode() {
  for i in "${!HOSTLIST[@]}"; do
    if [[ "${HOSTLIST[$i]}" = "${HOSTNAME}" ]]; then
       ((NEXT_NODE_INDEX = ${i}+1))
    fi
  done

  if [  ${NEXT_NODE_INDEX} -eq ${#HOSTLIST[*]} ]; then
    logStep "WARN: next index would be out of bounds loop back around"
    NEXT_NODE_INDEX="0"
  fi
     
  logStep "INFO: next node is ${HOSTLIST[${NEXT_NODE_INDEX}]}"
  echo "${HOSTLIST[${NEXT_NODE_INDEX}]}" > $LOCK_DIR/$S3_NODE_FILE 
}


myTask() {
  # log that this node is starting its task
  fetchS3NodeFile
  ACTIVE_HOST=`cat $LOCK_DIR/$S3_NODE_FILE`

  if [ ! ${ACTIVE_HOST} ]; then
    if [ "${HOSTNAME}" = "${HOSTLIST[${NEXT_NODE_INDEX}]}" ]; then
      ACTIVE_HOST=${HOSTNAME}
    fi
  fi

  while [ "${ACTIVE_HOST}" != "${HOSTNAME}" ]; do
    echo "Not my turn yet, sleeping for ${NODE_INTERVAL}"
    sleep ${NODE_INTERVAL}
    fetchS3NodeFile
    ACTIVE_HOST=`cat $LOCK_DIR/$S3_NODE_FILE`
  done

  logStep "NOTICE: Starting $TASK_FILE run"
  logStep  "NOTICE: Running $TASK_FILE"
  $TASK_FILE 
  echo $HOSTNAME > $LOCK_DIR/$S3_NODE_FILE 
  logStep "NOTICE: Completed $TASK_FILE run"
  getNextNode
}

getMessageLevel() {
  _MESSAGE=$*
  if [[ ${_MESSAGE} == *"FATAL"* ]]; then
    return 5
  elif [[ ${_MESSAGE} == *"ERROR"* ]]; then
    return 4
  elif [[ ${_MESSAGE} == *"NOTICE"* ]]; then
    return 3
  elif [[ ${_MESSAGE} == *"INFO"* ]]; then
    return 2      
  elif [[ ${_MESSAGE} == *"ALL"* ]]; then
    return 1
  else 
    return 0
  fi
}

# 1. 
# cron task every hour on every node
# 05 * * * * * /opt/jmiller/bin/mparicle_task.sh



##### START MAIN 
START=$(date +%s);

logStep "INFO: $0 triggered"

# Allow configuration options
if [ -f $CONFIG_FILE ]; then
  . $CONFIG_FILE
else
  logStep "FATAL: missing config file $CONFIG_FILE"
fi

# see if a lockfile exist already
checkLock

# if the lock didnt exis lets create it
createLock

# can we ls contents of the s3 bucket defined in s3-task-queue_task.conf?
verifyS3Access 

# run task
myTask 

# push up the next node in queue
putS3NodeFile


END=$(date +%s);
RUNTIME=`expr ${END} - ${START}`
logStep "INFO: Runtime Seconds - $RUNTIME"


# Remove the lock as the last task we have
removeLock




#!/bin/bash

function check_time {
   #start_time=2100
   #end_time=0355
  start_time=$1
  start_date=$(date +"%Y%m%d")
  end_time=$2
  current_datetime=$(date +%s)
  if [[ $start_time > $end_time ]]; then end_date=$(date --date="+1day" +"%Y%m%d")
  else
  end_date=$start_date
  fi
  fullStartTime="$start_date $start_time"
  fullEndTime="$end_date $end_time"
  fullStartTimeUnixTimeStamp=$(date +%s --date="$fullStartTime")
  fullEndTimeUnixTimeStamp=$(date +%s --date="$fullEndTime")
  if [[ $current_datetime  > $fullStartTimeUnixTimeStamp ]] && [[ $current_datetime <  $fullEndTimeUnixTimeStamp ]];
   then
    echo "work"
   else
      echo "sleep"
  fi

}

function worker {
 echo $1
}

function create_aws_profile {
 mkdir ~/.aws/  -p
 echo "
[default]
aws_access_key_id = $AWS_KEY
aws_secret_access_key = $AWS_SECRET
">~/.aws/credentials


 echo "
[default]
region = $DYNAMODB_REGION
output = json
">~/.aws/config

}

# main

create_aws_profile


while :
 do
  echo "loop"

  nexttoken='init'
  while [ -n "$nexttoken" ]
 do
   echo "nexttoken $nexttoken"
  case $nexttoken in
   init)
    json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 )
    ;;
   *)
   json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 --starting-token $nexttoken )
   ;;
  esac
 item=$( echo $json |jq -r '.Items[]' )
 worker "$item"
 echo "***** next item"
# echo '******* item'
# echo $item |  jq
 if [[ "$nexttoken" == "null" ]] ; then
  nexttoken=''
  echo "nexttoken  null"
 fi
 sleep 2
done


  echo "****======= next run"
  sleep 10
 done
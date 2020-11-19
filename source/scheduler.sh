#!/bin/bash

function log {
  case $LOG_TYPE in
    cloudwatch)
      echo "log > cloudwatch"
       ;;
    *)
     echo "$1"
    ;;
  esac
 

}

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
 local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
 local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
 local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
 local operational=$(echo $1 | jq -r '.operational[]' |tr -d '\n'  )
 local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
 local scheduler_type=$(echo $1 | jq -r '.scheduler_type[]' |tr -d '\n'  )
 local work_hours=$(echo $1 | jq -r '.work_hours[]' |tr -d '\n'  )
 local resource_type=$(echo $1 | jq -r '.resource_type[]' |tr -d '\n'  )
 echo "resource_id_type $resource_id_type"
 echo "resource_id $resource_id"
 echo "resource_region $resource_region"
 echo "operational $operational"
 echo "id $id"
 echo "scheduler_type $scheduler_type"
 echo "work_hours $work_hours"
 echo "resource_type $resource_type"
 echo "*****************"

 case $operational in
  true )
   log "run $resource_id"
   ;;
  *)
   log "id=$id   $operational not equal true , skip"
   ;;
 esac

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

  nexttoken='init'
  while [ -n "$nexttoken" ]
    do
     case $nexttoken in
        init)
         json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 )
         ;;
        *)
        json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 --starting-token $nexttoken )
        ;;
     esac
      nexttoken=$(echo $json |jq -r '.NextToken')
      item=$( echo $json |jq -r '.Items[]' )
      worker "$item"
      if [[ "$nexttoken" == "null" ]] ; then
       nexttoken=''
      fi
      sleep $SLEEP_NEXT_ITEM
      
    done


  log "****======= next run SLEEP_NEXT_RUN=$SLEEP_NEXT_RUN"
  sleep $SLEEP_NEXT_RUN
 done
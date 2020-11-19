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

function create_aws_profile {
 mkdir ~/.aws/  -p
 cat <<"EOF" >> ~/.aws/credentials
  [default]
  aws_access_key_id = $AWS_KEY
  aws_secret_access_key = $AWS_SECRET

EOF


cat <<"EOF" >> ~/.aws/config
[default]
region = $DYNAMODB_REGION
output = json


EOF



}

# main
create_aws_profile



while :
 do
  echo "loop"
  
  sleep 5
 done
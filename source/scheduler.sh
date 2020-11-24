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

function get_aurora_mysql_instance_type {
echo "instance type"
}


function aurora_mysql_instance_status {
aws rds describe-db-instances --db-instance-identifier $1 --region $2  --query 'DBInstances[*].DBInstanceStatus' --output text |tr -d '\n'
}

function aurora_mysql_instance_is_writer {
 #$1 instance
 #$2 region
cluster_id=$(aws rds describe-db-instances --db-instance-identifier  $1 --region $2  --query 'DBInstances[*].DBClusterIdentifier'  --output text | tr -d '\n' )
aws rds describe-db-clusters  --db-cluster-identifier $cluster_id  --region $2  --query "DBClusters[*].DBClusterMembers[?(DBInstanceIdentifier=='$1')].IsClusterWriter" --output text | tr -d '\n'
}

function aurora_mysql_instance_switch {
    local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
    local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
    log "run aurora mysql switch "
    time_to_run=$(check_time "$1" )
    echo "*** time to  $time_to_run"
    case $time_to_run in
      work)
        log "run work $work_instance_type "
        case $(aurora_mysql_instance_is_writer "$resource_id"  "$resource_region") in
         False)
          log "*** $resource_id Iswrite=False "
           case $(aurora_mysql_instance_status "$resource_id"  "$resource_region" ) in
             available)
              log "*** $resource_id = available ,  --== modify ==--"
              aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $work_instance_type --apply-immediately
             ;;
             *)
             log "*** $resource_id = not available  , skip modify"
             ;;
           esac
          ;;
         True)
           log "*** $resource_id Iswrite=True  , skip modify"
           ;;
       esac  
        #aws rds modify-db-instance  --db-instance-identifier database-1-instance-1-us-west-2b  --region us-west-2  --db-instance-class db.t3.small --apply-immediately --profile ol
      ;;

      sleep)
       log "run sleep $sleep_instance_type"
      ;;

      *)
      ;;


    esac

}



function ec2_check_status {
  aws ec2 describe-instances  --instance-ids $1  --region $2   --query 'Reservations[*].Instances[*].State.Name' --output text| tr -d '\n'

}

function ec2_get_instance_type {
 aws ec2 describe-instances  --instance-ids $1  --region $2   --query 'Reservations[*].Instances[*].InstanceType' --output text| tr -d '\n'
}

function ec2_SWITCH {
  log "***ec2_SWITCH"
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  time_to_run=$(check_time "$1" )
  echo "*** time to  $time_to_run"
  case $time_to_run in
    work)
       log "change  instance $resource_region $resource_id $id   to $work_instance_type "
       current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" )
       log "current instance type $current_instance_type"
       if [ "$current_instance_type" = "$work_instance_type" ]; then
           echo "istance type are equal "
       else
           echo "instance not equal => change."
            log " $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region )"
            log "sleep 60"
            sleep 60
            aws ec2 modify-instance-attribute     --instance-id $resource_id      --instance-type "{\"Value\": \"$work_instance_type\"}"  --region $resource_region
            aws ec2 start-instances --instance-ids $resource_id  --region $resource_region
       fi

      ;;
    sleep)
       log "change  instance $resource_region $resource_id $id   to $sleep_instance_type"
              current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" )
       log "current instance type $current_instance_type"
       if [ "$current_instance_type" = "$sleep_instance_type" ]; then
           echo "istance type are equal "
        else
           echo "instance not equal => change."
            log " $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region )"
            log "sleep 60"
            sleep 60
            aws ec2 modify-instance-attribute     --instance-id $resource_id      --instance-type "{\"Value\": \"$sleep_instance_type\"}"  --region $resource_region
            aws ec2 start-instances --instance-ids $resource_id  --region $resource_region
       fi
      ;;
    *)
     log "time to run < $time_to_run>  not supported"
    ;;
  esac

}

function ec2_ON_OFF {
  log "***ec2_ON_OFF"
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )

  time_to_run=$(check_time "$1" )
  echo "*** time to  $time_to_run"
  case $time_to_run in
    work)
       log "start instance $resource_region $resource_id_type $id"
       case $(ec2_check_status "$resource_id" "$resource_region" ) in
        running)
          log "$resource_id is running"
         ;;
       *)
          log "$(aws ec2 start-instances  --instance-ids $resource_id   --region $resource_region)"
         ;;
       esac

      ;;
    sleep)
       log "stop instance $resource_region $resource_id_type $id"
        case $(ec2_check_status "$resource_id" "$resource_region" ) in
        running)
           log "$(aws ec2 stop-instances  --instance-ids $resource_id   --region $resource_region)"
         ;;
       *)
          log "$resource_id  is  not run"
         ;;
       esac
      ;;
    *)
     log "time to run < $time_to_run>  not supported"
    ;;
  esac

}
function check_time {
  local work_hours=$(echo $1 | jq -r '.work_hours[]' |tr -d '\n'  )
  start_time=$(echo $work_hours |cut -d '-' -f1 | tr -d '\n')
  start_date=$(date +"%Y%m%d")
  end_time=$(echo $work_hours |cut -d '-' -f2 |tr -d '\n' )
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
  local operational=$(echo $1 | jq -r '.operational[]' |tr -d '\n'  )
  local resource_type=$(echo $1 | jq -r '.resource_type[]' |tr -d '\n'  )
  local scheduler_type=$(echo $1 | jq -r '.scheduler_type[]' |tr -d '\n'  )
  echo "*****************"
  case $operational in
     true )
      log "run $id"
       case $resource_type in
         ec2)
           log "run ec2 $resource_id"
            case $scheduler_type in
             ON_OFF)
                ec2_ON_OFF  "$1"
              ;;
             SWITCH)
                ec2_SWITCH "$1"
               ;;
             *)
               log  " ec2 $scheduler_type  not supported"
            esac
          ;;
         aurora_mysql_instance)
           log "run aurora_mysql $resource_id scheduler_type=$scheduler_type"
           case $scheduler_type in
             SWITCH)
                aurora_mysql_instance_switch "$1"
              ;;

              *)
                log  " ec2 $scheduler_type  not supported"
              ;;

           esac

          ;;
         *)
          log "resource_type $resource_type  not supported"
         ;;
       esac

      ;;
     *)
      log "id=$id   operational=$operational ; not equal true , skip"
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
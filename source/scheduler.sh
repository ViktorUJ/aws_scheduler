#!/bin/bash
# var
aurora_timeout=1200

#

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

function aurora_mysql_instance_type {
aws rds describe-db-instances --db-instance-identifier $1 --region $2  --query 'DBInstances[*].DBInstanceClass' --output text |tr -d '\n'
}


function aurora_mysql_instance_status {
aws rds describe-db-instances --db-instance-identifier $1 --region $2  --query 'DBInstances[*].DBInstanceStatus' --output text |tr -d '\n'
}

function aurora_mysql_instances_status {
   cluster_status="available"
   for instance in $1 ; do
     curent_status=$(aurora_mysql_instance_status "$instance" "$2")
     if [ ! "$curent_status" = "available" ]; then
          cluster_status="not_ready"
     fi
    done
    echo "$cluster_status"

 }


function aurora_mysql_instance_is_writer {
 #$1 instance
 #$2 region
cluster_id=$(aws rds describe-db-instances --db-instance-identifier  $1 --region $2  --query 'DBInstances[*].DBClusterIdentifier'  --output text | tr -d '\n' )
aws rds describe-db-clusters  --db-cluster-identifier $cluster_id  --region $2  --query "DBClusters[*].DBClusterMembers[?(DBInstanceIdentifier=='$1')].IsClusterWriter" --output text | tr -d '\n'
}

function get_instances_aurora_mysql_cluster {
   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --query "DBClusters[*].DBClusterMembers[*].DBInstanceIdentifier" --output text | tr -d '\n'
}

function wait_available_instance_aurora_mysql {
  declare -i timeout_max=$aurora_timeout
  declare -i timeout=0
  curent_status=$(aurora_mysql_instances_status "$1" "$2")
  log "current status $curent_status   $1  $2"
  while [[ "$curent_status" = "not_ready" && $timeout -lt $timeout_max ]]; do
    sleep 30; timeout+=30 ; echo "wait,  curent_status = $curent_status   30 sek ($timeout) of $timeout_max"
    curent_status=$(aurora_mysql_instances_status "$1" "$2")
   done
}

function get_writer_aurora_mysql_cluster {
   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text | tr -d '\n'
}

function get_readers_aurora_mysql_cluster {
   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text
}


function  aurora_mysql_cluster_switch {
  #aws rds  failover-db-cluster --db-cluster-identifier  sh --profile old --region us-west-2 --target-db-instance-identifier sh-instance-1-us-west-2b
    log " **** run aurora_mysql_cluster_switch"
    local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    local sleep_reader_instance_type=$(echo $1 | jq -r '.sleep_reader_instance_type[]' |tr -d '\n'  )
    local sleep_writer_instance_type=$(echo $1 | jq -r '.sleep_writer_instance_type[]' |tr -d '\n'  )
    local work_reader_instance_type=$(echo $1 | jq -r '.work_reader_instance_type[]' |tr -d '\n'  )
    local work_writer_instance_type=$(echo $1 | jq -r '.work_writer_instance_type[]' |tr -d '\n'  )
    time_to_run=$(check_time "$1" )
    echo "*** time to  $time_to_run"
    current_instances_id=$(get_instances_aurora_mysql_cluster "$resource_id" "$resource_region" )
    current_writer_id=$(get_writer_aurora_mysql_cluster "$resource_id" "$resource_region")
    log "*** instances = $current_instances_id"
    log "*** writer = $current_writer_id"
    cluster_status=$(aurora_mysql_instances_status "$current_instances_id"  "$resource_region")
    log "*** cluster status = $cluster_status"
    case $cluster_status in
     available)
          case $time_to_run in
           work)
             log "*** work"
             #modify
             readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
             new_writer=$(echo $readers | cut -d' ' -f1 | tr -d '\n' )
             log "readers = $readers"
             log " new_writer = $new_writer"
             log  "modify"
             aws rds modify-db-instance  --db-instance-identifier $new_writer  --region $resource_region  --db-instance-class $work_writer_instance_type --apply-immediately --no-paginate
             log "wait "
             sleep 120
             wait_available_instance_aurora_mysql "$new_writer" "$resource_region"
             #aws rds  failover-db-cluster --db-cluster-identifier  $resource_id   --region $resource_region  --target-db-instance-identifier $new_writer --no-paginate
            # sleep 60
             readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
             log "*** new reader = $readers"

             ##aws rds  failover-db-cluster --db-cluster-identifier  sh --profile old --region us-west-2 --target-db-instance-identifier sh-instance-1-us-west-2b
            #
           ;;
           sleep)
             log "*** sleep"
           ;;
           *)
             log "time to work $time_to_run not supported"
           ;;

          esac
     ;;
     *)
       log "cluster  now available  for modify ,  skip"
      ;;
    esac

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
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" )
                log "current instance type $current_instance_type"
                if [ "$current_instance_type" = "$work_instance_type" ]; then
                    echo "istance type are equal "
                else
                    echo "instance not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $work_instance_type --apply-immediately
                fi

             ;;
             *)
             log "*** $resource_id = not available for modify  , skip modify"
             ;;
           esac
          ;;
         True)
           log "*** $resource_id Iswrite=True  , skip modify"
           ;;
       esac  

      ;;

      sleep)
       log "run sleep $sleep_instance_type"
               case $(aurora_mysql_instance_is_writer "$resource_id"  "$resource_region") in
         False)
          log "*** $resource_id Iswrite=False "
           case $(aurora_mysql_instance_status "$resource_id"  "$resource_region" ) in
             available)
               log "*** $resource_id = available ,  --== modify ==--"
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" )
                log "current instance type $current_instance_type"
                if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                    echo "istance type are equal "
                else
                    echo "instance not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $sleep_instance_type --apply-immediately
                fi

             ;;
             *)
             log "*** $resource_id = not available for modify  , skip modify"
             ;;
           esac
          ;;
         True)
           log "*** $resource_id Iswrite=True  , skip modify"
           ;;
       esac


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
         aurora_mysql_cluster)
           aurora_mysql_cluster_switch "$1"
           
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
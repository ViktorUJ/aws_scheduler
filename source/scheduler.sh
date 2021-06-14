#!/bin/bash
# set default variables {

if [ -z "$SLEEP_NEXT_RUN" ]; then
     SLEEP_NEXT_RUN="60"
fi

if [ -z "$SLEEP_NEXT_ITEM" ]; then
     SLEEP_NEXT_ITEM="1"
fi

if [ -z "$AWS_IAM_TYPE" ]; then
     AWS_IAM_TYPE="ROLE"
fi

if [ -z "$LOG_TYPE" ]; then
     LOG_TYPE="stdout"
fi

if [ -z "$AURORA_TIMEOUT" ]; then
     AURORA_TIMEOUT=1200
fi

#set default variables }

function log {
  case $LOG_TYPE in
    cloudwatch)
      echo "log > cloudwatch"
       ;;
    stdout)
     echo "$1"
    ;;
    *)
     echo "$1"
    ;;
  esac
 

}

function aurora_mysql_instance_type {
#  $1 instance id
#  $2 region
#  $3 aws profile
local aws_profile="$3"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi

aws rds describe-db-instances --db-instance-identifier $1 --region $2  --profile $aws_profile --query 'DBInstances[*].DBInstanceClass' --output text |tr -d '\n'
}


function aurora_mysql_instance_status {
 local aws_profile="$3"
 if [ -z "$aws_profile" ]; then
      aws_profile="default"
 fi
aws rds describe-db-instances --db-instance-identifier $1 --region $2 --profile $aws_profile  --query 'DBInstances[*].DBInstanceStatus' --output text |tr -d '\n'
}

function aurora_mysql_instances_status {
   local aws_profile="$3"
   if [ -z "$aws_profile" ]; then
        aws_profile="default"
   fi
   local cluster_id=$(aws rds describe-db-instances --db-instance-identifier  $(echo $1 | cut -d ' ' -f1 | tr -d '\n'  ) --region $2  --profile $aws_profile --query 'DBInstances[*].DBClusterIdentifier'  --output text | tr -d '\n' )
   local current_cluster_status=$(aws rds describe-db-clusters  --db-cluster-identifier $cluster_id  --region $2 --profile $aws_profile   --query "DBClusters[*].Status" --output text | tr -d '\n')
   if [ ! "$current_cluster_status" = "available" ]; then
          local cluster_status=cluster_status="not_ready"
     else
       local cluster_status="available"
   fi

   for instance in $1 ; do
     local curent_status=$(aurora_mysql_instance_status "$instance" "$2" "$aws_profile")
     if [ ! "$curent_status" = "available" ]; then
         local  cluster_status="not_ready"
     fi
    done
    echo "$cluster_status"

 }


function aurora_mysql_instance_is_writer {
 #$1 instance
 #$2 region
 local aws_profile="$3"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi
#
#    log "db-instance-identifier= $1   region = $2   profile=$aws_profile "
cluster_id=$(aws rds describe-db-instances --db-instance-identifier  $1 --region $2 --profile $aws_profile --query 'DBInstances[*].DBClusterIdentifier'  --output text | tr -d '\n' )
aws rds describe-db-clusters  --db-cluster-identifier $cluster_id  --region $2  --profile $aws_profile  --query "DBClusters[*].DBClusterMembers[?(DBInstanceIdentifier=='$1')].IsClusterWriter" --output text | tr -d '\n'
}

function get_instances_aurora_mysql_cluster {
   local aws_profile="$3"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi

   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --profile $aws_profile --query "DBClusters[*].DBClusterMembers[*].DBInstanceIdentifier" --output text | tr -d '\n'
}

function wait_available_instance_aurora_mysql {
  declare -i timeout_max=$AURORA_TIMEOUT
  declare -i timeout=0
  local aws_profile="$4"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi
  curent_status=$(aurora_mysql_instances_status "$1" "$2" "$aws_profile")
  log "id=$3 current status $curent_status   $1  $2"
  while [[ "$curent_status" = "not_ready" && $timeout -lt $timeout_max ]]; do
    sleep 30; timeout+=30 ; log "id=$3 wait,  curent_status = $curent_status   30 sek ($timeout) of $timeout_max"
    curent_status=$(aurora_mysql_instances_status "$1" "$2" "$aws_profile")
   done
}

function get_writer_aurora_mysql_cluster {
    local aws_profile="$3"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi

   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --profile $aws_profile --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text | tr -d '\n'
}

function get_readers_aurora_mysql_cluster {
 local aws_profile="$3"
if [ -z "$aws_profile" ]; then
     aws_profile="default"
fi

   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2 --profile $aws_profile  --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text
}

function get_instance_type_aurora_mysql {
 local aws_profile="$3"
 if [ -z "$aws_profile" ]; then
     aws_profile="default"
 fi

   aws rds describe-db-instances --db-instance-identifier  $1 --region $2 --profile $aws_profile  --query 'DBInstances[*].DBInstanceClass'  --output text | tr -d '\n'
}

function  aurora_mysql_cluster_on_off {
    local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
    if [ -z "$aws_profile" ]; then
     aws_profile="default"
    fi
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    time_to_run=$(check_time "$1" )
    # check cluster status
    # local current_instances_id=$(get_instances_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile")
   # local cluster_status=$(aurora_mysql_instances_status "$current_instances_id"  "$resource_region" "$aws_profile")
    local  cluster_info=$(aws rds describe-db-clusters     --db-cluster-identifier $resource_id --profile $aws_profile --region $resource_region)
    local cluster_status=$(echo $cluster_info | jq -r '.DBClusters[].Status' |tr -d '\n')
    log "id=$id *** time to  $time_to_run  resource_id=$resource_id  cluster_status=$cluster_status resource_region=$resource_region aws_profile=$aws_profile"
    case $time_to_run in
      work)
         case $cluster_status in
          stopped)
            # start cluster
            aws rds start-db-cluster  --db-cluster-identifier $resource_id  --profile $aws_profile --region $resource_region
            log "id=$id  sleep 150"
            sleep 150
           ;;

           *)
             log "id=$id  cluster_status=$cluster_status , skip"

           ;;
         esac
       ;;
      sleep)
         case $cluster_status in
           available)
            aws rds stop-db-cluster  --db-cluster-identifier $resource_id  --profile $aws_profile --region $resource_region
            log "id=$id  sleep 150"
            sleep 150
            # cluster stop

           ;;
          *)
             log "id=$id  cluster_status=$cluster_status , skip"
           ;;
         esac

       ;;
      *)
        log "id=$id time to run < $time_to_run>  not supported"
       ;; 
    esac
    
    
}

function  aurora_mysql_cluster_switch {
    local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
    if [ -z "$aws_profile" ]; then
     aws_profile="default"
    fi

    local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    local sleep_reader_instance_type=$(echo $1 | jq -r '.sleep_reader_instance_type[]' |tr -d '\n'  )
    local sleep_writer_instance_type=$(echo $1 | jq -r '.sleep_writer_instance_type[]' |tr -d '\n'  )
    local work_reader_instance_type=$(echo $1 | jq -r '.work_reader_instance_type[]' |tr -d '\n'  )
    local work_writer_instance_type=$(echo $1 | jq -r '.work_writer_instance_type[]' |tr -d '\n'  )
    log "id=$id **** run aurora_mysql_cluster_switch"
    time_to_run=$(check_time "$1" )
    log "id=$id *** time to  $time_to_run  resource_id=$resource_id  resource_region=$resource_region aws_profile=$aws_profile"
    local current_instances_id=$(get_instances_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile")
    local current_writer_id=$(get_writer_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile")
    log "id=$id *** instances = $current_instances_id"
    log "id=$id *** writer = $current_writer_id"
    local cluster_status=$(aurora_mysql_instances_status "$current_instances_id"  "$resource_region" "$aws_profile")
    log "id=$id *** cluster status = $cluster_status  profile = $aws_profile"
    case $cluster_status in
     available)
          case $time_to_run in
           work)
             log "id=$id *** work"
             #  modify writer
            local  current_witer_instance_type=$(get_instance_type_aurora_mysql "$current_writer_id" "$resource_region" "$aws_profile" )
             if [ "$current_witer_instance_type" = "$work_writer_instance_type" ]; then
                    log "id=$id $current_writer_id instance type are equal "
                else
                    log "id=$id $current_writer_id instance  type not equal => change."
                    local readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile" )
                    local new_writer=$(echo $readers | cut -d' ' -f1 | tr -d '\n' )
                    log "id=$id readers = $readers"
                    log "id=$id new_writer = $new_writer"
                    log  "id=$id modify"
                    aws rds modify-db-instance  --db-instance-identifier $new_writer  --region $resource_region --profile $aws_profile  --db-instance-class $work_writer_instance_type --apply-immediately --no-paginate
                    log "id=$id wait " ;  sleep 300
                    wait_available_instance_aurora_mysql "$new_writer" "$resource_region" "$id" "$aws_profile"
                    aws rds  failover-db-cluster --db-cluster-identifier  $resource_id   --region $resource_region  --profile $aws_profile  --target-db-instance-identifier $new_writer --no-paginate
                    log "id=$id wait " ; sleep 300
             fi
             #modify readers
             local readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile" )
             log "id=$id *** new reader = $readers"
                for instance in $readers ; do
                  local current_reader_instance_type=$(get_instance_type_aurora_mysql "$instance" "$resource_region" "$aws_profile" )
                  if [ "$current_reader_instance_type" = "$work_reader_instance_type" ]; then
                        log "id=$id $instance instance type are equal "
                    else
                        log "id=$id $instance instance type  not equal => change."
                        aws rds modify-db-instance  --db-instance-identifier $instance  --region $resource_region  --profile $aws_profile --db-instance-class $work_reader_instance_type --apply-immediately --no-paginate
                        log "id=$id sleep 300"
                        sleep 300
                        wait_available_instance_aurora_mysql "$instance" "$resource_region" "$id" "$aws_profile"
                  fi
                done
           ;;
           sleep)
             log "id=$id *** sleep"
              #  modify writer
             local current_witer_instance_type=$(get_instance_type_aurora_mysql "$current_writer_id" "$resource_region" "$aws_profile" )
             if [ "$current_witer_instance_type" = "$sleep_writer_instance_type" ]; then
                    log "id=$id $current_writer_id instance type are equal "
                else
                    log "id=$id $current_writer_id instance not equal => change."
                    local readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile" )
                    local new_writer=$(echo $readers | cut -d' ' -f1 | tr -d '\n' )
                    log "id=$id readers = $readers"
                    log "id=$id  new_writer = $new_writer"
                    log  "id=$id modify"
                    aws rds modify-db-instance  --db-instance-identifier $new_writer  --region $resource_region  --profile $aws_profile --db-instance-class $sleep_writer_instance_type --apply-immediately --no-paginate
                    log "id=$id wait " ;  sleep 300
                    wait_available_instance_aurora_mysql "$new_writer" "$resource_region" "$id" "$aws_profile"
                    aws rds  failover-db-cluster --db-cluster-identifier  $resource_id   --region $resource_region  --profile $aws_profile --target-db-instance-identifier $new_writer --no-paginate
                    log "id=$id wait " ; sleep 300
             fi
             #modify readers
             local readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" "$aws_profile" )
             log "id=$id *** new reader = $readers"
             for instance in $readers ; do
                  local current_reader_instance_type=$(get_instance_type_aurora_mysql "$instance" "$resource_region" "$aws_profile" )
                  if [ "$current_reader_instance_type" = "$sleep_reader_instance_type" ]; then
                        log "id=$id $instance instance type are equal "
                    else
                        log "id=$id $instance instance type not equal => change."
                        aws rds modify-db-instance  --db-instance-identifier $instance  --region $resource_region  --profile $aws_profile --db-instance-class $sleep_reader_instance_type --apply-immediately --no-paginate
                        log "id=$id sleep 300"
                        sleep 300
                        wait_available_instance_aurora_mysql "$instance" "$resource_region" "$id" "$aws_profile"
                  fi
             done
           ;;
           *)
             log "id=$id time to work $time_to_run not supported"
           ;;

          esac
     ;;
     *)
       log "id=$id cluster  not available  for modify ,  skip"
      ;;
    esac

}

function aurora_mysql_instance_switch {
   local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
    if [ -z "$aws_profile" ]; then
     aws_profile="default"
    fi
    local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
    local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
    local force_modify=$(echo $1 | jq -r '.force_modify[]' |tr -d '\n'  )
    log "id=$id run aurora mysql switch "
    time_to_run=$(check_time "$1" )
    log "id=$id *** time to  $time_to_run"
        case $force_modify in
        true)
          local is_writer="False"
          ;;
        *)
          local is_writer=$(aurora_mysql_instance_is_writer "$resource_id"  "$resource_region" "$aws_profile" )
         ;;
        esac
    log "id=$id is_writer=$is_writer "
    case $time_to_run in
      work)
        log "id=$id *** $resource_id is_writer=$is_writer "
        case $is_writer in
         False)
 #         log "id=$id *** $resource_id Iswrite=False "
           case $(aurora_mysql_instances_status "$resource_id"  "$resource_region" "$aws_profile" ) in
             available)
               log "id=$id *** $resource_id = available ,  --== modify ==--"
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" "$aws_profile" )
                log "id=$id current instance type $current_instance_type"
                if [ "$current_instance_type" = "$work_instance_type" ]; then
                    log "id=$id $resource_id instance type are equal "
                else
                    log "id=$id $resource_id instance not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region --profile "$aws_profile" --db-instance-class $work_instance_type --apply-immediately
                    log "id=$id sleep 300"
                    sleep 300
                    wait_available_instance_aurora_mysql "$resource_id" "$resource_region" "$id" "$aws_profile"
                fi

             ;;
             *)
             log "id=$id *** $resource_id = not available for modify  , skip modify"
             ;;
           esac
          ;;
         True)
           log "id=$id *** $resource_id Iswrite=True  , skip modify"
           ;;
       esac  

      ;;

      sleep)
        log "id=$id run sleep $sleep_instance_type"
        log "id=$id run work $work_instance_type force_modify=$force_modify "

       case $is_writer in
         False)
          log "id=$id *** $resource_id Iswrite=False "
           case $(aurora_mysql_instances_status "$resource_id"  "$resource_region" "$aws_profile" ) in
             available)
               log "id=$id *** $resource_id = available ,  --== modify ==--"
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" "$aws_profile" )
                log "id=$id current instance type $current_instance_type"
                if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                    log "id=$id $resource_id instance type are equal "
                else
                    log "id=$id $resource_id instance type not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region --profile "$aws_profile"  --db-instance-class $sleep_instance_type --apply-immediately
                    log "id=$id sleep 300"
                    sleep 300
                    wait_available_instance_aurora_mysql "$resource_id" "$resource_region" "$id" "$aws_profile"
                fi

             ;;
             *)
             log "id=$id *** $resource_id = not available for modify  , skip modify"
             ;;
           esac
          ;;
         True)
           log "id=$id *** $resource_id Iswrite=True  , skip modify"
           ;;
       esac


      ;;

      *)
      ;;


    esac

}



function ec2_check_status {
   local aws_profile="$3"
   if [ -z "$aws_profile" ]; then
     aws_profile="default"
   fi
  aws ec2 describe-instances  --instance-ids $1  --region $2  --profile $aws_profile  --query 'Reservations[*].Instances[*].State.Name' --output text| tr -d '\n'

}
function ec2_wait_status {
   local aws_profile="$5"
   if [ -z "$aws_profile" ]; then
     aws_profile="default"
   fi
  local ec2_status=$(ec2_check_status $1 $2 $aws_profile )
  local desire_status="$3"
  declare -i ec2_timeout_max=$AURORA_TIMEOUT
  declare -i ec2_timeout=0
  while [[ ! "$desire_status" = "$ec2_status" && $ec2_timeout -lt $ec2_timeout_max ]]; do
    sleep 30; ec2_timeout+=10 ; log "id=$4 wait,  curent_status = $ec2_status   10 sek ($ec2_timeout) of $ec2_timeout_max"
    local ec2_status=$(ec2_check_status $1 $2 $aws_profile)
  done

}

function ec2_get_instance_type {
 local aws_profile="$3"
 if [ -z "$aws_profile" ]; then
    aws_profile="default"
 fi
 aws ec2 describe-instances  --instance-ids $1  --region $2 --profile  $aws_profile --query 'Reservations[*].Instances[*].InstanceType' --output text| tr -d '\n'
}

function ec2_SWITCH {
  local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
  if [ -z "$aws_profile" ]; then
    aws_profile="default"
  fi
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  log "id=$id ***ec2_SWITCH"
  time_to_run=$(check_time "$1" )
  log "id=$id  *** time to  $time_to_run"
  case $resource_id_type  in
      id)
        case $time_to_run in
          work)
             log "id=$id  change  instance $resource_region $resource_id $id   to $work_instance_type "
             current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" "$aws_profile")
             log "id=$id  current instance type $current_instance_type"
             if [ "$current_instance_type" = "$work_instance_type" ]; then
                 log "id=$id  istance type are equal "
             else
                 log "id=$id  instance not equal => change."
                  log "id=$id  $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region --profile $aws_profile)"
                  log "id=$id  sleep 60" ; sleep 60
                  aws ec2 modify-instance-attribute     --instance-id $resource_id   --profile $aws_profile    --instance-type "{\"Value\": \"$work_instance_type\"}"  --region $resource_region
                  aws ec2 start-instances --instance-ids $resource_id  --region $resource_region --profile $aws_profile
             fi

            ;;
          sleep)
             log "id=$id  change  instance $resource_region $resource_id $id   to $sleep_instance_type"
                    current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" $aws_profile )
             log "id=$id  current instance type $current_instance_type"
             if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                 log "id=$id  instance type are equal "
              else
                  log "id=$id  instance not equal => change."
                  log "id=$id   $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region --profile $aws_profile )"
                  log "id=$id  sleep 60" ; sleep 60
                  aws ec2 modify-instance-attribute     --instance-id $resource_id   --profile $aws_profile    --instance-type "{\"Value\": \"$sleep_instance_type\"}"  --region $resource_region
                  aws ec2 start-instances --instance-ids $resource_id  --profile $aws_profile --region $resource_region
             fi
            ;;
          *)
           log "id=$id  time to run < $time_to_run>  not supported"
          ;;
        esac
    ;;
    tag)
     local tag_name=$(echo $resource_id | cut -d':' -f1 |tr -d '\n')
     local tag_value=$(echo $resource_id | cut -d':' -f2 |tr -d '\n')
     log "id=$id   tag , tag_name=$tag_name , tag_value=$tag_value"
     if [ "$resource_region" = "all" ] ; then
       resource_region=$(aws ec2 describe-regions --profile $aws_profile --output text --query 'Regions[*].RegionName')
      fi
     for region in $resource_region ; do
       log "id=$id  region = $region "
       case $time_to_run in
           work)
             instance_ids=$(aws ec2 describe-instances  --query 'Reservations[*].Instances[*].InstanceId' --region $region --profile $aws_profile  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              not_equal_instances=''
               for instance_id in $instance_ids ;do
                 log "id=$id  region $region   current instance = $instance_id"
                 current_instance_type=$(ec2_get_instance_type "$instance_id" "$region" "$aws_profile" )
                 log "id=$id  current instance type $current_instance_type"
                 if [ "$current_instance_type" = "$work_instance_type" ]; then
                    log "id=$id  istance type are equal "
                  else
                    log "id=$id instance not equal => change."
                     not_equal_instances+="$instance_id "
                 fi
                done
               if [ ! -z "$not_equal_instances" ] ; then
               log "id=$id  not  equal instances = $not_equal_instances "
               log "id=$id  $(aws ec2 stop-instances  --instance-ids $not_equal_instances --profile $aws_profile --region $region )"
               log "id=$id  sleep 60" ; sleep 60
               for modify_insances_id in $not_equal_instances ; do
                 aws ec2 modify-instance-attribute  --instance-id $modify_insances_id   --profile $aws_profile    --instance-type "{\"Value\": \"$work_instance_type\"}"  --region $region
                done
               aws ec2 start-instances --instance-ids $not_equal_instances --profile $aws_profile --region $region
               fi
             fi
             ;;
           sleep)
             instance_ids=$(aws ec2 describe-instances  --profile $aws_profile --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              not_equal_instances=''
              for instance_id in $instance_ids ;do
                 current_instance_type=$(ec2_get_instance_type "$instance_id" "$region" "$aws_profile")
                 log "id=$id  current instance type $current_instance_type"
                 if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                    log "id=$id  instance type are equal "
                  else
                    log "id=$id  instance not equal => change."
                     not_equal_instances+="$instance_id "
                 fi
               done
              if [ ! -z "$not_equal_instances" ] ; then
                 log "id=$id  not  equal instances = $not_equal_instances "
                 log "id=$id  $(aws ec2 stop-instances  --instance-ids $not_equal_instances --profile $aws_profile --region $region )"
                 log "id=$id  sleep 60" ; sleep 60
                 for modify_insances_id in $not_equal_instances ; do
                     aws ec2 modify-instance-attribute  --instance-id $modify_insances_id  --profile $aws_profile  --instance-type "{\"Value\": \"$sleep_instance_type\"}"  --region $region
                  done
                 aws ec2 start-instances --instance-ids $not_equal_instances --region $region --profile $aws_profile

              fi
             fi
             ;;
           *)
             log "id=$id  time to run < $time_to_run>  not supported"
            ;;
       esac
     done
    ;;
    *)
      log "id=$id  resource_id_type=$resource_id_type not supported "
    ;;
  esac 
}

function ec2_ON_OFF {
  local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
  if [ -z "$aws_profile" ]; then
   aws_profile="default"
  fi
  log "ec2_ON_OFF aws_profile=$aws_profile "
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  log "id=$id ***ec2_ON_OFF"
  time_to_run=$(check_time "$1" )
  log "id=$id tags  : $tag_name $tag_value  "
  log "id=$id *** time to  $time_to_run"
  case $resource_id_type  in
    id)
      case $time_to_run in
        work)
         log "id=$id start instance $resource_region $resource_id_type $id"
         case $(ec2_check_status "$resource_id" "$resource_region" "$aws_profile" ) in
           running)
            log "id=$id $resource_id is running"
           ;;

           stopped)
            log "id=$id $(aws ec2 start-instances  --instance-ids $resource_id  --profile $aws_profile  --region $resource_region)"
            ec2_wait_status "$resource_id" "$resource_region" "running" "$id" "$aws_profile"
            ;;
          *)
           log "id=$id $resource_id is status not stopped , skip"
         ;;
       esac

      ;;
    sleep)
       log "id=$id stop instance $resource_region $resource_id_type $id"
        case $(ec2_check_status "$resource_id" "$resource_region" "$aws_profile" ) in
        running)
           log "id=$id $(aws ec2 stop-instances  --instance-ids $resource_id   --region $resource_region --profile $aws_profile )"
           ec2_wait_status "$resource_id" "$resource_region" "stopped" "$id" "$aws_profile"
         ;;
       *)
          log "id=$id $resource_id  is  not run"
         ;;
       esac
      ;;
    *)
     log "id=$id time to run < $time_to_run>  not supported"
    ;;
  esac

    ;;
    tag)
      log "id=$id ec2 tag"
      local tag_name=$(echo $resource_id | cut -d':' -f1 |tr -d '\n')
      local tag_value=$(echo $resource_id | cut -d':' -f2 |tr -d '\n')
      if [ "$resource_region" = "all" ] ; then
       resource_region=$(aws ec2 describe-regions --output text --profile $aws_profile --query 'Regions[*].RegionName')
      fi
      for region in $resource_region ; do
       log "id=$id region = $region "
       case $time_to_run in
           work)
             instance_ids=$(aws ec2 describe-instances  --profile $aws_profile --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=stopped" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id instances in region $region   = $instance_ids"
              aws ec2 start-instances  --region $region --profile $aws_profile --instance-ids  $instance_ids
              ec2_wait_status "$instance_ids" "$region" "running" "$id" "$aws_profile"
             fi
             ;;
           sleep)
             instance_ids=$(aws ec2 describe-instances --profile $aws_profile  --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              aws ec2 stop-instances  --region $region --profile $aws_profile --instance-ids  $instance_ids
              ec2_wait_status "$instance_ids" "$region" "stopped" "$id" "$aws_profile"
             fi
             ;;
           *)
             log "id=$id time to run < $time_to_run>  not supported"
            ;;
       esac
      done
    ;;

  esac

}

function rds_get_status {
  local aws_profile="$3"
  if [ -z "$aws_profile" ]; then
     aws_profile="default"
  fi
  aws rds describe-db-instances  --db-instance-identifier $1 --region $2 --profile $aws_profile --query 'DBInstances[*].DBInstanceStatus' --output text| tr -d '\n'
}

function rds_get_instance_type {
  local aws_profile="$3"
  if [ -z "$aws_profile" ]; then
     aws_profile="default"
  fi
  aws rds describe-db-instances  --db-instance-identifier $1 --region $2 --profile $aws_profile --query 'DBInstances[*].DBInstanceClass' --output text| tr -d '\n'
}

function rds_ON_OFF {
  local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
  if [ -z "$aws_profile" ]; then
   aws_profile="default"
  fi

  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  log "id=$id rds ON_OFF"
  time_to_run=$(check_time "$1" )
  log "id=$id *** time to  $time_to_run"
  current_status=$(rds_get_status "$resource_id"  "$resource_region" "$aws_profile")
  log "id=$id ****  current_status=$current_status     "
  case $time_to_run in
    work)
      case $current_status in
         available)
          log "id=$id *** instance  is $current_status , not need start"
          ;;
         stopped)
          aws rds start-db-instance  --db-instance-identifier $resource_id --region $resource_region --profile $aws_profile --no-paginate
          ;;
         *)
         log "id=$id wait status (available or stopped) "
        ;;
      esac
      ;;
    sleep)
      case $current_status in
        available)
         aws rds stop-db-instance  --db-instance-identifier $resource_id --region $resource_region --profile $aws_profile --no-paginate
         ;;
        stopped)
          log "id=$id *** instance  is $current_status , not need stop"
         ;;
        *)
        log "id=$id wait status (available or stopped) "
       ;;
     esac
       ;;
  esac

}

function rds_SWITCH {
  local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
  if [ -z "$aws_profile" ]; then
   aws_profile="default"
  fi

  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  time_to_run=$(check_time "$1" )
  log "id=$id rds SWITCH"
  log "id=$id *** time to  $time_to_run"
  current_instance_type=$(rds_get_instance_type "$resource_id" "$resource_region" "$aws_profile")
  current_status=$(rds_get_status "$resource_id"  "$resource_region" "$aws_profile")
  log "id=$id ****  current_status=$current_status     "
  case $current_status in
    available)
      log "id=$id *** modify"
      case $time_to_run in
        sleep)
          if [[ "$current_instance_type" == "$sleep_instance_type" ]] ; then
            log "id=$id instance are equal , skip"
           else
             log "id=$id modify"
             aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --profile $aws_profile --db-instance-class $sleep_instance_type --apply-immediately --no-paginate
          fi
        ;;
        work)
          if [[ "$current_instance_type" == "$work_instance_type" ]] ; then
            log "id=$id instance are equal , skip"
           else
             log "id=$id modify"
             aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region --profile $aws_profile --db-instance-class $work_instance_type --apply-immediately --no-paginate
          fi
        ;;
    esac
     ;;
    *)
      log "id=$id status not available , skip"
     ;;
    esac
}

function check_asg_update {
# $1 - aws profile
# $2 - region
# $3 - id
# $4 - desired_capacity
# $5 - max_capacity
# $6 - min_capacity
 local need_update="false"
 local asg_info=$(aws autoscaling describe-auto-scaling-groups  --auto-scaling-group-name $3 --profile $1 --region $2)
 local current_desired_capacity=$(echo  "$asg_info" |  jq -r '.AutoScalingGroups[].DesiredCapacity' |tr -d '\n')
 local current_min_capacity=$(echo  "$asg_info" |  jq -r '.AutoScalingGroups[].MinSize' |tr -d '\n')
 local current_max_capacity=$(echo  "$asg_info" |  jq -r '.AutoScalingGroups[].MaxSize' |tr -d '\n')
 if [ "$current_min_capacity" != "$6" ] || [ "$current_max_capacity" != "$5" ]  ; then
   local need_update="true"
 fi
 echo $need_update
}

function asg_SWITCH {
  log "id=$id  asg_SWITCH"
  local aws_profile=$(echo $1 | jq -r '.aws_profile[]' |tr -d '\n'  )
  if [ -z "$aws_profile" ]; then
   aws_profile="default"
  fi

  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local work_desired_capacity=$(echo $1 | jq -r '.work_desired_capacity[]' |tr -d '\n'  )
  local work_max_capacity=$(echo $1 | jq -r '.work_max_capacity[]' |tr -d '\n'  )
  local work_min_capacity=$(echo $1 | jq -r '.work_min_capacity[]' |tr -d '\n'  )

  local sleep_desired_capacity=$(echo $1 | jq -r '.sleep_desired_capacity[]' |tr -d '\n'  )
  local sleep_max_capacity=$(echo $1 | jq -r '.sleep_max_capacity[]' |tr -d '\n'  )
  local sleep_min_capacity=$(echo $1 | jq -r '.sleep_min_capacity[]' |tr -d '\n'  )
  local time_to_run=$(check_time "$1" )
#
  log "resource_id=$resource_id  resource_region=$resource_region work_desired_capacity=$work_desired_capacity work_max_capacity=$work_max_capacity work_min_capacity=$work_min_capacity sleep_desired_capacity=$sleep_desired_capacity sleep_max_capacity=$sleep_max_capacity sleep_min_capacity=$sleep_min_capacity"

  log "id=$id  time_to_run= $time_to_run"
  case $time_to_run in
    sleep)
      local current_need_asg_update=$(check_asg_update "$aws_profile" "$resource_region" "$resource_id" "$sleep_desired_capacity" "$sleep_max_capacity" "$sleep_min_capacity")
      log "id=$id  current_need_asg_update = $current_need_asg_update"
      case $current_need_asg_update in
       true)
         aws autoscaling update-auto-scaling-group  --auto-scaling-group-name $resource_id  --desired-capacity $sleep_desired_capacity  --maxsize $sleep_max_capacity  --min-size $sleep_min_capacity --profile $aws_profile --region $resource_region
         ;;
       false)
          log "id=$id  not need update asg"
       ;;
      esac
      ;;
    work)
      local current_need_asg_update=$(check_asg_update "$aws_profile" "$resource_region" "$resource_id" "$sleep_desired_capacity" "$sleep_max_capacity" "$sleep_min_capacity")
      log "id=$id  current_need_asg_update = $current_need_asg_update"
      case $current_need_asg_update in
       true)
         aws autoscaling update-auto-scaling-group  --auto-scaling-group-name $resource_id  --desired-capacity $work_desired_capacity  --maxsize $work_max_capacity  --min-size $work_min_capacity --profile $aws_profile --region $resource_region
         ;;
       false)
          log "id=$id  not need update asg"
       ;;
      esac

      ;;
  esac

}


function check_time {
  local period_type=$(echo $1 | jq -r '.period_type[]' |tr -d '\n'  )
  case $period_type in
    work-hours)
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
    ;;
   weekend)
     local current_day=$(date +%a | tr -d '\n')
     local weekend_days=$(echo $1 | jq -r '.weekend_days[]' |tr -d '\n'  )
     local check_day=$(echo $weekend_days | grep $current_day  | tr -d '\n')
     if [ -z "$check_day" ] ; then
        echo "work"
       else
         echo "sleep"
     fi

    ;;
   work-hours_weekend)
     local current_day=$(date +%a | tr -d '\n')
     local weekend_days=$(echo $1 | jq -r '.weekend_days[]' |tr -d '\n'  )
     local check_day=$(echo $weekend_days | grep $current_day  | tr -d '\n')
     if [ -z "$check_day" ] ; then
        check_day_status="work"
       else
         check_day_status="sleep"
     fi
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
       check_time_status="work"
      else
        check_time_status="sleep"
     fi
     if [[ "$check_time_status" = "sleep" ]] || [[ "$check_day_status" = "sleep" ]] ; then
         echo "sleep"
        else
         echo "work"
     fi
    ;;

  esac


}

function worker {
  local operational=$(echo $1 | jq -r '.operational[]' |tr -d '\n'  )
  local resource_type=$(echo $1 | jq -r '.resource_type[]' |tr -d '\n'  )
  local scheduler_type=$(echo $1 | jq -r '.scheduler_type[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  # set lock
  if [[ "$id" == "all" ]] ; then
     log "id=$id , skip"
    else
      time_stamp=$(date +%G:%m:%d_%k:%M:%S | tr -d '\n'| tr -d ' ')
      log "id=$id set lock $time_stamp"
      aws dynamodb update-item --table-name $DYNAMODB_TABLE_NAME --region $DYNAMODB_REGION  --key '{"id":{"S":"'$id'"}}' --attribute-updates '{"lock": {"Value": {"S":"true='$time_stamp'"},"Action": "PUT"}}'
      echo "*****************"
      case $operational in
         true )
           case $resource_type in
             all)
              ;;
             ec2)
               log "id=$id run ec2 $resource_id"
                case $scheduler_type in
                 ON_OFF)
                    ec2_ON_OFF  "$1"
                  ;;
                 SWITCH)
                    ec2_SWITCH "$1"
                   ;;
                 *)
                   log  "id=$id ec2 $scheduler_type  not supported"
                   ;;
                esac
              ;;
            asg_SWITCH)
              asg_SWITCH "$1"
              ;;
             rds)
               log "id=$id run rds $resource_id"
               case $scheduler_type in
                 ON_OFF)
                  rds_ON_OFF "$1"
                 ;;
                 SWITCH)
                  rds_SWITCH "$1"
                 ;;
                 *)
                  log "id=$id rds $scheduler_type  not supported"
                 ;;
               esac
             ;;
             aurora_mysql_cluster_switch)
               aurora_mysql_cluster_switch "$1"
              ;;

             aurora_mysql_cluster_on_off)
               aurora_mysql_cluster_on_off "$1"
              ;;

             aurora_mysql_instance)
               log "id=$id run aurora_mysql_instance $resource_id scheduler_type=$scheduler_type"
               case $scheduler_type in
                 SWITCH)
                    aurora_mysql_instance_switch "$1"
                  ;;

                  *)
                    log  "id=$id ec2 $scheduler_type  not supported"
                  ;;

               esac

              ;;
             *)
              log "id=$id resource_type $resource_type  not supported"
             ;;
           esac

          ;;
         *)
          log "id=$id   operational=$operational ; not equal true , skip"
          ;;
      esac
      log "id=$id disable lock "
      aws dynamodb update-item   --table-name $DYNAMODB_TABLE_NAME --region $DYNAMODB_REGION  --key '{"id":{"S":"'$id'"}}' --attribute-updates '{"lock": {"Value": {"S": ""},"Action": "PUT"}}'

  fi
}

function create_aws_profile {
 mkdir ~/.aws/  -p
 case $AWS_IAM_TYPE in
 ROLE)
   log "*** use aws iam role"
   echo "
[default]
region = $DYNAMODB_REGION
output = json
">~/.aws/config
   ;;
 KEY)
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

   ;;
 CUSTOM_PROFILE)
   log " AWS_IAM_TYPE = $AWS_IAM_TYPE  "
   echo "$AWS_CUSTOM_CONFIG" | base64 -d >~/.aws/config
   echo "$AWS_CUSTOM_CREDENTIALS" | base64 -d >~/.aws/credentials
   ;;
 *)
   log "value of  AWS_IAM_TYPE = $AWS_IAM_TYPE    not supported "
  ;;
 esac




}
#=========================================================================
# main
create_aws_profile
while :
 do
  nexttoken='init'
  while [ -n "$nexttoken" ]
    do
     case $nexttoken in
        init)
         json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --region $DYNAMODB_REGION --max-items 1 )
         ;;
        *)
        json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --region $DYNAMODB_REGION  --max-items 1 --starting-token $nexttoken )
        ;;
     esac
      nexttoken=$(echo $json |jq -r '.NextToken')
      item=$( echo $json |jq -r '.Items[]' )
      lock_status=$(echo $item | jq -r '.lock[]' 2>/dev/null |grep "true" |tr -d '\n'  )
      id=$(echo $item | jq -r '.id[]' |tr -d '\n'  )
      # lock status
      global_operational=$(aws dynamodb get-item  --table-name $DYNAMODB_TABLE_NAME   --region $DYNAMODB_REGION    --consistent-read --key '{"id": {"S": "all"}}' | jq -r '.Item.operational.S'  |tr -d '\n'   )
      if [[ "$global_operational" == "true" ]] && [[ -z "$lock_status" ]]; then
        worker "$item" &
        else
         log "id=$id  ,global_operational = $global_operational ,lock_status = $lock_status  ,  skip "
      fi
      if [[ "$nexttoken" == "null" ]] ; then
       nexttoken=''
      fi
      sleep $SLEEP_NEXT_ITEM
    done
  log "****======= next run SLEEP_NEXT_RUN=$SLEEP_NEXT_RUN"
  sleep $SLEEP_NEXT_RUN
 done
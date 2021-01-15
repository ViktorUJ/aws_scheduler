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
   cluster_id=$(aws rds describe-db-instances --db-instance-identifier  $(echo $1 | cut -d ' ' -f1 | tr -d '\n'  ) --region $2  --query 'DBInstances[*].DBClusterIdentifier'  --output text | tr -d '\n' )
   current_cluster_status=$(aws rds describe-db-clusters  --db-cluster-identifier $cluster_id  --region $2  --query "DBClusters[*].Status" --output text | tr -d '\n')
   if [ ! "$current_cluster_status" = "available" ]; then
          cluster_status=cluster_status="not_ready"
     else
       cluster_status="available"
   fi

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
  log "id=$3 current status $curent_status   $1  $2"
  while [[ "$curent_status" = "not_ready" && $timeout -lt $timeout_max ]]; do
    sleep 30; timeout+=30 ; log "id=$3 wait,  curent_status = $curent_status   30 sek ($timeout) of $timeout_max"
    curent_status=$(aurora_mysql_instances_status "$1" "$2")
   done
}

function get_writer_aurora_mysql_cluster {
   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text | tr -d '\n'
}

function get_readers_aurora_mysql_cluster {
   aws rds describe-db-clusters  --db-cluster-identifier $1 --region $2  --query 'DBClusters[*].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text
}

function get_instance_type_aurora_mysql {
   aws rds describe-db-instances --db-instance-identifier  $1 --region $2  --query 'DBInstances[*].DBInstanceClass'  --output text | tr -d '\n'
}

function  aurora_mysql_cluster_switch {
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
    log "id=$id *** time to  $time_to_run"
    current_instances_id=$(get_instances_aurora_mysql_cluster "$resource_id" "$resource_region" )
    current_writer_id=$(get_writer_aurora_mysql_cluster "$resource_id" "$resource_region")
    log "id=$id *** instances = $current_instances_id"
    log "id=$id *** writer = $current_writer_id"
    cluster_status=$(aurora_mysql_instances_status "$current_instances_id"  "$resource_region")
    log "id=$id *** cluster status = $cluster_status"
    case $cluster_status in
     available)
          case $time_to_run in
           work)
             log "id=$id *** work"
             #  modify writer
             current_witer_instance_type=$(get_instance_type_aurora_mysql "$current_writer_id" "$resource_region")
             if [ "$current_witer_instance_type" = "$work_writer_instance_type" ]; then
                    log "id=$id $current_writer_id instance type are equal "
                else
                    log "id=$id $current_writer_id instance  type not equal => change."
                    readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
                    new_writer=$(echo $readers | cut -d' ' -f1 | tr -d '\n' )
                    log "id=$id readers = $readers"
                    log "id=$id new_writer = $new_writer"
                    log  "id=$id modify"
                    aws rds modify-db-instance  --db-instance-identifier $new_writer  --region $resource_region  --db-instance-class $work_writer_instance_type --apply-immediately --no-paginate
                    log "id=$id wait " ;  sleep 300
                    wait_available_instance_aurora_mysql "$new_writer" "$resource_region" "$id"
                    aws rds  failover-db-cluster --db-cluster-identifier  $resource_id   --region $resource_region  --target-db-instance-identifier $new_writer --no-paginate
                    log "id=$id wait " ; sleep 300
             fi
             #modify readers
             readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
             log "id=$id *** new reader = $readers"
                for instance in $readers ; do
                  current_reader_instance_type=$(get_instance_type_aurora_mysql "$instance" "$resource_region")
                  if [ "$current_reader_instance_type" = "$work_reader_instance_type" ]; then
                        log "id=$id $instance instance type are equal "
                    else
                        log "id=$id $instance instance type  not equal => change."
                        aws rds modify-db-instance  --db-instance-identifier $instance  --region $resource_region  --db-instance-class $work_reader_instance_type --apply-immediately --no-paginate
                        log "id=$id sleep 30"
                        sleep 30
                        wait_available_instance_aurora_mysql "$instance" "$resource_region" "$id"
                  fi
                done
           ;;
           sleep)
             log "id=$id *** sleep"
              #  modify writer
             current_witer_instance_type=$(get_instance_type_aurora_mysql "$current_writer_id" "$resource_region")
             if [ "$current_witer_instance_type" = "$sleep_writer_instance_type" ]; then
                    log "id=$id $current_writer_id instance type are equal "
                else
                    log "id=$id $current_writer_id instance not equal => change."
                    readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
                    new_writer=$(echo $readers | cut -d' ' -f1 | tr -d '\n' )
                    log "id=$id readers = $readers"
                    log "id=$id  new_writer = $new_writer"
                    log  "id=$id modify"
                    aws rds modify-db-instance  --db-instance-identifier $new_writer  --region $resource_region  --db-instance-class $sleep_writer_instance_type --apply-immediately --no-paginate
                    log "id=$id wait " ;  sleep 300
                    wait_available_instance_aurora_mysql "$new_writer" "$resource_region" "$id"
                    aws rds  failover-db-cluster --db-cluster-identifier  $resource_id   --region $resource_region  --target-db-instance-identifier $new_writer --no-paginate
                    log "id=$id wait " ; sleep 300
             fi
             #modify readers
             readers=$(get_readers_aurora_mysql_cluster "$resource_id" "$resource_region" )
             log "id=$id *** new reader = $readers"
             for instance in $readers ; do
                  current_reader_instance_type=$(get_instance_type_aurora_mysql "$instance" "$resource_region")
                  if [ "$current_reader_instance_type" = "$sleep_reader_instance_type" ]; then
                        log "id=$id $instance instance type are equal "
                    else
                        log "id=$id $instance instance type not equal => change."
                        aws rds modify-db-instance  --db-instance-identifier $instance  --region $resource_region  --db-instance-class $sleep_reader_instance_type --apply-immediately --no-paginate
                        log "id=$id sleep 30"
                        sleep 30
                        wait_available_instance_aurora_mysql "$instance" "$resource_region" "$id"
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
    local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
    local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
    local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
    local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
    local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
    local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
    log "id=$id run aurora mysql switch "
    time_to_run=$(check_time "$1" )
    log "id=$id *** time to  $time_to_run"
    case $time_to_run in
      work)
        log "id=$id run work $work_instance_type "
        case $(aurora_mysql_instance_is_writer "$resource_id"  "$resource_region") in
         False)
          log "id=$id *** $resource_id Iswrite=False "
           case $(aurora_mysql_instances_status "$resource_id"  "$resource_region" ) in
             available)
               log "id=$id *** $resource_id = available ,  --== modify ==--"
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" )
                log "id=$id current instance type $current_instance_type"
                if [ "$current_instance_type" = "$work_instance_type" ]; then
                    log "id=$id $resource_id instance type are equal "
                else
                    log "id=$id $resource_id instance not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $work_instance_type --apply-immediately
                    log "id=$id sleep 30"
                    sleep 30
                    wait_available_instance_aurora_mysql "$resource_id" "$resource_region" "$id"
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
       case $(aurora_mysql_instance_is_writer "$resource_id"  "$resource_region") in
         False)
          log "id=$id *** $resource_id Iswrite=False "
           case $(aurora_mysql_instances_status "$resource_id"  "$resource_region" ) in
             available)
               log "id=$id *** $resource_id = available ,  --== modify ==--"
                current_instance_type=$(aurora_mysql_instance_type "$resource_id" "$resource_region" )
                log "id=$id current instance type $current_instance_type"
                if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                    log "id=$id $resource_id instance type are equal "
                else
                    log "id=$id $resource_id instance type not equal => change."
                    aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $sleep_instance_type --apply-immediately
                    log "id=$id sleep 30"
                    sleep 30
                    wait_available_instance_aurora_mysql "$resource_id" "$resource_region" "$id"
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
  aws ec2 describe-instances  --instance-ids $1  --region $2   --query 'Reservations[*].Instances[*].State.Name' --output text| tr -d '\n'

}

function ec2_get_instance_type {
 aws ec2 describe-instances  --instance-ids $1  --region $2   --query 'Reservations[*].Instances[*].InstanceType' --output text| tr -d '\n'
}

function ec2_SWITCH {
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
             current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" )
             log "id=$id  current instance type $current_instance_type"
             if [ "$current_instance_type" = "$work_instance_type" ]; then
                 log "id=$id  istance type are equal "
             else
                 log "id=$id  instance not equal => change."
                  log "id=$id  $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region )"
                  log "id=$id  sleep 60" ; sleep 60
                  aws ec2 modify-instance-attribute     --instance-id $resource_id      --instance-type "{\"Value\": \"$work_instance_type\"}"  --region $resource_region
                  aws ec2 start-instances --instance-ids $resource_id  --region $resource_region
             fi

            ;;
          sleep)
             log "id=$id  change  instance $resource_region $resource_id $id   to $sleep_instance_type"
                    current_instance_type=$(ec2_get_instance_type "$resource_id" "$resource_region" )
             log "id=$id  current instance type $current_instance_type"
             if [ "$current_instance_type" = "$sleep_instance_type" ]; then
                 log "id=$id  instance type are equal "
              else
                  log "id=$id  instance not equal => change."
                  log "id=$id   $(aws ec2 stop-instances  --instance-ids $resource_id  --region $resource_region )"
                  log "id=$id  sleep 60" ; sleep 60
                  aws ec2 modify-instance-attribute     --instance-id $resource_id      --instance-type "{\"Value\": \"$sleep_instance_type\"}"  --region $resource_region
                  aws ec2 start-instances --instance-ids $resource_id  --region $resource_region
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
       resource_region=$(aws ec2 describe-regions --output text --query 'Regions[*].RegionName')
      fi
     for region in $resource_region ; do
       log "id=$id  region = $region "
       case $time_to_run in
           work)
             instance_ids=$(aws ec2 describe-instances  --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              not_equal_instances=''
               for instance_id in $instance_ids ;do
                 log "id=$id  region $region   current instance = $instance_id"
                 current_instance_type=$(ec2_get_instance_type "$instance_id" "$region" )
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
               log "id=$id  $(aws ec2 stop-instances  --instance-ids $not_equal_instances --region $region )"
               log "id=$id  sleep 60" ; sleep 60
               for modify_insances_id in $not_equal_instances ; do
                 aws ec2 modify-instance-attribute  --instance-id $modify_insances_id      --instance-type "{\"Value\": \"$work_instance_type\"}"  --region $region
                done
               aws ec2 start-instances --instance-ids $not_equal_instances --region $region
               fi
             fi
             ;;
           sleep)
             instance_ids=$(aws ec2 describe-instances  --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              not_equal_instances=''
              for instance_id in $instance_ids ;do
                 current_instance_type=$(ec2_get_instance_type "$instance_id" "$region" )
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
                 log "id=$id  $(aws ec2 stop-instances  --instance-ids $not_equal_instances --region $region )"
                 log "id=$id  sleep 60" ; sleep 60
                 for modify_insances_id in $not_equal_instances ; do
                     aws ec2 modify-instance-attribute  --instance-id $modify_insances_id      --instance-type "{\"Value\": \"$sleep_instance_type\"}"  --region $region
                  done
                 aws ec2 start-instances --instance-ids $not_equal_instances --region $region

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
         case $(ec2_check_status "$resource_id" "$resource_region" ) in
        running)
          log "id=$id $resource_id is running"
         ;;
        *)
          log "id=$id $(aws ec2 start-instances  --instance-ids $resource_id   --region $resource_region)"
         ;;
       esac

      ;;
    sleep)
       log "id=$id stop instance $resource_region $resource_id_type $id"
        case $(ec2_check_status "$resource_id" "$resource_region" ) in
        running)
           log "id=$id $(aws ec2 stop-instances  --instance-ids $resource_id   --region $resource_region)"
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
       resource_region=$(aws ec2 describe-regions --output text --query 'Regions[*].RegionName')
      fi
      for region in $resource_region ; do
       log "id=$id region = $region "
       case $time_to_run in
           work)
             instance_ids=$(aws ec2 describe-instances  --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=stopped" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id instances in region $region   = $instance_ids"
              aws ec2 start-instances  --region $region --instance-ids  $instance_ids
             fi
             ;;
           sleep)
             instance_ids=$(aws ec2 describe-instances  --query 'Reservations[*].Instances[*].InstanceId' --region $region  --output text --filters "Name=tag:$tag_name,Values=$tag_value" "Name=instance-state-name,Values=running" )
             if [ ! -z "$instance_ids" ] ; then
              log "id=$id  instances in region $region   = $instance_ids"
              aws ec2 stop-instances  --region $region --instance-ids  $instance_ids
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
  aws rds describe-db-instances  --db-instance-identifier $1 --region $2 --query 'DBInstances[*].DBInstanceStatus' --output text| tr -d '\n'
}

function rds_get_instance_type {
  aws rds describe-db-instances  --db-instance-identifier $1 --region $2 --query 'DBInstances[*].DBInstanceClass' --output text| tr -d '\n'
}

function rds_ON_OFF {
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  log "id=$id rds ON_OFF"
  time_to_run=$(check_time "$1" )
  log "id=$id *** time to  $time_to_run"
  current_status=$(rds_get_status "$resource_id"  "$resource_region" )
  log "id=$id ****  current_status=$current_status     "
  case $time_to_run in
    work)
      case $current_status in
         available)
          log "id=$id *** instance  is $current_status , not need start"
          ;;
         stopped)
          aws rds start-db-instance  --db-instance-identifier $resource_id --region $resource_region --no-paginate
          ;;
         *)
         log "id=$id wait status (available or stopped) "
        ;;
      esac
      ;;
    sleep)
      case $current_status in
        available)
         aws rds stop-db-instance  --db-instance-identifier $resource_id --region $resource_region --no-paginate
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
  local resource_id_type=$(echo $1 | jq -r '.resource_id_type[]' |tr -d '\n'  )
  local resource_id=$(echo $1 | jq -r '.resource_id[]' |tr -d '\n'  )
  local resource_region=$(echo $1 | jq -r '.resource_region[]' |tr -d '\n'  )
  local work_instance_type=$(echo $1 | jq -r '.work_instance_type[]' |tr -d '\n'  )
  local sleep_instance_type=$(echo $1 | jq -r '.sleep_instance_type[]' |tr -d '\n'  )
  local id=$(echo $1 | jq -r '.id[]' |tr -d '\n'  )
  time_to_run=$(check_time "$1" )
  log "id=$id rds SWITCH"
  log "id=$id *** time to  $time_to_run"
  current_instance_type=$(rds_get_instance_type "$resource_id" "$resource_region")
  current_status=$(rds_get_status "$resource_id"  "$resource_region" )
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
             aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $sleep_instance_type --apply-immediately --no-paginate
          fi
        ;;
        work)
          if [[ "$current_instance_type" == "$work_instance_type" ]] ; then
            log "id=$id instance are equal , skip"
           else
             log "id=$id modify"
             aws rds modify-db-instance  --db-instance-identifier $resource_id  --region $resource_region  --db-instance-class $work_instance_type --apply-immediately --no-paginate
          fi
        ;;
    esac
     ;;
    *)
      log "id=$id status not available , skip"
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
      log "id=$id set lock "
      aws dynamodb update-item     --table-name scheduler_dev --key '{"id":{"S":"'$id'"}}' --attribute-updates '{"lock": {"Value": {"S": "true: '$(date +%G:%m:%d_%k:%M:%S | tr -d '\n')'"},"Action": "PUT"}}'

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
             aurora_mysql_cluster)
               aurora_mysql_cluster_switch "$1"

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
      aws dynamodb update-item     --table-name scheduler_dev --key '{"id":{"S":"'$id'"}}' --attribute-updates '{"lock": {"Value": {"S": ""},"Action": "PUT"}}'

  fi
}

function create_aws_profile {
 mkdir ~/.aws/  -p
 case $AWS_IAM_ROLE in
 true)
   log "*** use aws iam role"
   ;;
 *)
  echo "
  [default]
  aws_access_key_id = $AWS_KEY
  aws_secret_access_key = $AWS_SECRET
  ">~/.aws/credentials
   ;;
 esac


 echo "
[default]
region = $DYNAMODB_REGION
output = json
">~/.aws/config

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
         json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 )
         ;;
        *)
        json=$(aws dynamodb scan --table-name  $DYNAMODB_TABLE_NAME  --max-items 1 --starting-token $nexttoken )
        ;;
     esac
      nexttoken=$(echo $json |jq -r '.NextToken')
      item=$( echo $json |jq -r '.Items[]' )
      lock_status=$(echo $item | jq -r '.lock[]' 2>/dev/null |grep "true" |tr -d '\n'  )
      id=$(echo $item | jq -r '.id[]' |tr -d '\n'  )
      # lock status
      global_operational=$(aws dynamodb get-item  --table-name $DYNAMODB_TABLE_NAME     --consistent-read --key '{"id": {"S": "all"}}' | jq -r '.Item.operational.S'  |tr -d '\n'   )
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
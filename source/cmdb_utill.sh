#!/bin/bash
command=$1

# ./cmdb_utill.sh  set_target_time_stamp  --target_time_stamp "00000" --id 'test'
# ./cmdb_utill.sh  set_env_time_hours  --hours "2" --id 'test'
# ./cmdb_utill.sh  set_env_time_hours  --hours "2" --id 'test' --skip_lock 'true'


if [ -z "$command" ]; then
    echo "*** command not set "
    exit 1
fi
while [[ $# > 0 ]]; do
    key="$1"
    case "$key" in
      --target_time_stamp)
         target_time_stamp="$2"
         shift
      ;;
      --id)
         id="$2"
         shift
      ;;
      --hours)
         hours="$2"
         shift
      ;;
    --skip_lock)
         skip_lock="$2"
         shift
         ;;

      *)
      ;;
    esac
    shift
  done

global_operational=$(aws dynamodb get-item  --table-name $DYNAMODB_TABLE_NAME   --region $DYNAMODB_REGION    --consistent-read --key '{"id": {"S": "all"}}' | jq -r '.Item.operational.S' 2>/dev/null |tr -d '\n'   )
lock_status=$(aws dynamodb get-item  --table-name $DYNAMODB_TABLE_NAME   --region $DYNAMODB_REGION    --consistent-read --key '{"id": {"S": "'$id'"}}'  |jq -r '.Item.lock[]' 2>/dev/null |tr -d '\n')

function set_target_time_stamp {
   if [[ "$global_operational" == "true" ]] && [[ -z "$lock_status" ]] || [[ "$skip_lock" == "true" ]]; then
     echo "update . id=$id  global_operational=$global_operational  lock_status=$lock_status"
     aws dynamodb update-item   --table-name $DYNAMODB_TABLE_NAME --region $DYNAMODB_REGION  --key '{"id":{"S":"'$1'"}}' --attribute-updates '{"target_time_stamp": {"Value": {"S": "'$2'"},"Action": "PUT"}}'
    else
     echo "can't update . id=$id  global_operational=$global_operational   lock_status=$lock_status"
   fi
}
# main --------
case $command in
   set_target_time_stamp)
     echo "*** set_target_time_stamp to $target_time_stamp "
     set_target_time_stamp "$id" "$target_time_stamp"
   ;;
   set_env_time_hours)
     echo "*** set_env_time_hours to $hours hours "
     target_time_stamp=$(echo "$(date +%s)+$hours*3600" | bc)
     set_target_time_stamp "$id" "$target_time_stamp"
   ;;

   *)
    echo "*** command not found . $0"
   ;;
esac

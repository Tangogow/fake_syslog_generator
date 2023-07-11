#!/bin/bash

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo -e "Usage: $0 <number_of_logs> <logs_per_second> <log_size> [<log_path>]\n"
  echo "You may be restricted by the number of logs per second, depending on your OS and disk IO's"
  echo "logs_per_second: in seconds (minimum 1)"
  echo "log_size: in bytes for each log entry"
  echo "log_path: the path of your log file. By default /var/log/messages (optional)"
  exit 1
fi

# trap Ctrl+C to display report
trap ctrl_c INT

service rsyslog start || rsyslogd # forcing

number_of_logs=$1
logs_per_second=$2
log_size=$3
log_path=$4
logs_generated=0

if [ -z "$log_path" ]; then
  $log_path="/var/log/messages"
fi
if [ ! -f "$log_path" ]; then
  touch $log_path
fi
logger -f $log_path

function report {
    duration=$(($end_time - $start_time))
    duration_secs=$duration
    if [ $duration -lt 60 ]; then
        duration=$duration" secs"
    elif [ $duration -lt 3600 ]; then
        duration=$(($duration / 60))" mins"
    else
        duration=$(($duration / 3600))" hours"
    fi
    estimated_duration=$(($logs_generated / $logs_per_second))
    real_logs_per_second=$(($logs_generated / $duration_secs))
    total_size=$(($logs_generated * $log_size))
    total_size_bytes=$total_size
    if [ $total_size -lt 1024 ]; then
        total_size=$total_size" B"
    elif [ $total_size -lt 1048576 ]; then
        total_size=$(($total_size / 1024))" KB"
    elif [ $total_size -lt 1073741824 ]; then
        total_size=$(($total_size / 1048576))" MB"
    else
        total_size=$(($total_size / 1073741824))" GB"
    fi

    echo "===FAKE LOGS REPORT==="
    echo "Logs generated     " $logs_generated
    echo "Wanted logs/s      " $logs_per_second
    echo "Real logs/s        " $real_logs_per_second
    echo "Total size         " $total_size
    echo "Estimated Duration " $estimated_duration
    echo "Real Duration      " $duration

    result="$logs_generated,$real_logs_per_second,$total_size_bytes,$duration_secs"
    echo $result > /var/log/$CONTAINER_NAME.log
    exit 0
}

function ctrl_c {
    end_time=$(date +%s)
    report
}

start_time=$(date +%s)

function generate_log_entry {
  local message=""
  local current_length=0

  # Append random data until log size is reached
  while [[ "$current_length" -lt "$log_size" ]]; do
    local random_data=$(head -c $((log_size - current_length)) /dev/urandom | tr -dc 'a-zA-Z0-9')
    message+="$random_data"
    current_length=${#message}
  done

  logger -t FAKE -p user.info "$message"
}

sleep_duration=$(awk "BEGIN {print 1/$logs_per_second}")

# Generate logs until the desired number is reached
while [[ "$logs_generated" -lt "$number_of_logs" ]]; do
  generate_log_entry
  logs_generated=$((logs_generated + 1))
  logs_per_second_count=$((logs_per_second_count + 1))
  
  if [[ "$logs_per_second_count" -eq "$logs_per_second" ]]; then
    echo "Generated $logs_per_second_count logs"
    logs_per_second_count=0
  fi
  echo "Logs/s: " `awk -v d1="$(date --date='-1 second' +'%b %d %H:%M:%S')" -v d2="$(date +'%b %d %H:%M:%S')" \
'$0 > d1 && $0 < d2 || $0 ~ d2' /var/log/syslog | wc -l`
  sleep "$sleep_duration"
done

end_time=$(date +%s)
report
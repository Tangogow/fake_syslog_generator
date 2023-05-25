#!/bin/bash

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <number_of_logs> <logs_per_second> <log_size>"
  echo "You may be restricted by the number of logs per second, depending on your OS and disk IO's"
  echo "logs_per_second: in seconds (minimum 1)"
  echo "log_size: in bytes for each log entry"
  exit 1
fi

# trap Ctrl+C to display report
trap ctrl_c INT

number_of_logs=$1
logs_per_second=$2
log_size=$3

logs_generated=0

function report {
    duration=$((end_time - start_time))
    if [ $duration -lt 60 ]; then
        duration=$duration" secs"
    elif [ $duration -lt 3600 ]; then
        duration=$((duration / 60))" mins"
    else
        duration=$((duration / 3600))" hours"
    fi
    total_size=$(($logs_generated * $log_size))
    if [ $total_size -lt 1024 ]; then
        total_size=$total_size" B"
    elif [ $total_size -lt 1048576 ];
        total_size=$((total_size / 1024))" KB"
    elif [ $total_size -lt 1073741824 ];
        total_size=$((total_size / 1048576))" MB"
    else
        total_size=$((total_size / 1073741824))" GB"
    fi
    echo "===FAKE LOGS REPORT==="
    echo "Logs generated  " $logs_generated
    echo "Logs per second " $logs_per_second
    echo "Total size      " $total_size
    echo "Duration        " $duration
    exit 0
}

function ctrl_c {
    end_time=$(date +%s)
    report
}

start_time=$(date +%s)
logger -t FAKE -p user.info "===========FAKE LOGS============="
# Generate a fake syslog entry
generate_log_entry() {
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

# Calculate sleep duration based on logs per second
sleep_duration=$(awk "BEGIN {print 1/$logs_per_second}")

# Generate logs until the desired number is reached
while [[ "$logs_generated" -lt "$number_of_logs" ]]; do
  generate_log_entry
  logs_generated=$((logs_generated + 1))
  logs_per_second_count=$((logs_per_second_count + 1))
  
  # Output the number of logs generated per second
  if [[ "$logs_per_second_count" -eq "$logs_per_second" ]]; then
    echo "Generated $logs_per_second_count logs"
    logs_per_second_count=0
  fi
  echo "Logs/s: " `grep -c "$(date --date='1 hour ago' + '%b %d %H:%M:%S')" /var/log/syslog`
  sleep "$sleep_duration"
done

end_time=$(date +%s)
report
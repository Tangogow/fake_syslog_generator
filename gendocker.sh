#!/bin/bash

# Parsing Args
action=$1
range_min=$2
range_max=$3
log_number=$4
logs_per_second=$5
log_size=$6

ip="172.0."
name="gll"
image="gll"
network="gll" 
volume="/var/lib/docker/volumes/logs/_data"

function usage {
    echo "
Usage: ./gendocker.sh <start|stop|restart|create|rm|recreate|run|exec|gen|logs> <rangemin> <rangemax> [<number_of_logs> <logs_per_seconde> <size_of_logs>]
Example: 
    ./gendocker.sh run 1 20                   Create and start 20 containers
    ./gendocker.sh gen 1 20 10000 100 100     Generate 10000 logs of 100 bytes at the rate of 100 logs/s on each container
    ./gendocker.sh logs 1 20                  Wait for the logs to come and report.

Other command:
    ./gendocker.sh rm 1 20                    Kill and remove containers
    ./gendocker.sh restart 1 10               Restart the container from 1 to 10
    ./gendocker.sh exec 5 10 \"echo hello\"   Injecting command into container 5 to 10 (background mode)"
    exit 1
}

actionArray=("start" "stop" "restart" "create" "rm" "recreate" "run" "exec" "gen" "logs")

if [[ ! " ${actionArray[@]} " =~ " ${action} " ]]; then
    echo "Wrong action command: $action"
    usage
fi

if [[ $action == "exec" ]]; then
    exec_command=$4
    log_number=""
fi

if [[ -z $range_max ]]; then
    range_max=$range_min
fi
if [[ $range_min -lt 1 || $range_max -lt 1 ]]; then
    echo "Wrong range. Need postive integers"
    usage
elif [[ $range_min -gt $range_max ]]; then
    echo "Wrong range. Rangemax should be higher than rangemin"
    usage
fi
if [[ $action == "gen" ]]; then
    if [[ $log_number -lt 1 || $logs_per_second -lt 1 || $log_size -lt 1 ]]; then
        echo "Wrong number of logs and/or logs per second and/or size. Need postive integers"
        usage
    fi
fi

logs_generated=0
wanted_logs_per_second=0
real_logs_per_second=0
total_size_bytes=0
estimated_duration=0
duration_secs=0

function formatDuration {
    seconds=$1
    if [[ $seconds -lt 60 ]]; then
        echo "$seconds secs"
    elif [[ $seconds -lt 3600 ]]; then
        seconds=$(round $seconds/60)
        echo "$seconds mins"
    else
        seconds=$(round $seconds/3600)
        echo "$seconds hours"
    fi
}

function formatSize {
    total_size=$1
    if [[ $total_size -lt 1024 ]]; then
        echo "$total_size B"
    elif [[ $total_size -lt 1048576 ]]; then
        total_size=$(round $total_size/1024)
        echo "$total_size KB"
    elif [[ $total_size -lt 1073741824 ]]; then
        total_size=$(round $total_size/1048576)
        echo "$total_size MB"
    else
        total_size=$(round $total_size/1073741824)
        echo "$total_size GB"
    fi
}

function round {
    printf "%.0f" $(($1))
}

if [[ $action == "gen" ]]; then
    rm -f $volume/*
elif [[ $action == "logs" ]]; then
    while [[ $(ls -1 $volume | wc -l) -ne $((range_max - range_min + 1)) ]]; do
        echo "Waiting for logs... Logs present: $(ls -1 $volume | wc -l)"
        sleep 1
    done
    for file in $(ls $volume); do
        while IFS=',' read -ra values; do
            if [[ ${#values[@]} -eq 6 ]]; then
                logs_generated=$((logs_generated + values[0]))
                wanted_logs_per_second=$((wanted_logs_per_second + values[1]))
                real_logs_per_second=$((real_logs_per_second + values[2]))
                total_size_bytes=$((total_size_bytes + values[3]))
                if [[ values[4] -gt $estimated_duration_secs ]]; then # get max value
                    estimated_duration_secs=${values[4]}
                fi
                if [[ values[5] -gt $real_duration_secs ]]; then
                    real_duration_secs=${values[5]}
                fi
            fi
        done < "$volume/$file"
    done
    echo "=== FAKE LOG REPORT ==="
    echo "Number container   " $(ls -1 $volume | wc -l)
    echo "Logs generated     " $logs_generated
    echo "Wanted Log/s       " $wanted_logs_per_second
    echo "Logs/s             " $real_logs_per_second
    echo "Total size         " $(formatSize $total_size_bytes)
    echo "Estimated Duration " $(formatDuration $estimated_duration_secs)
    echo "Real Duration      " $(formatDuration $real_duration_secs)
    exit 0
fi

digit3=0
digit4=0
function ip_increment(i) {
    ip="$ip.$digit3.$digit4"
    digit4=$(($digit4 + 1))
    if [[ $digit4 -gt 255]]; then
        $digit3=$(($digit3 + 1))
        $digit4=0
    fi
}

for (( i=range_min; i<=range_max; i++ )); do
    ip_increment $i
    if [[ $action == "start" ]]; then
        docker start $name$i
        echo "Container $name$i started"
    elif [[ $action == "stop" ]]; then
        docker stop $name$i
        echo "Container $name$i stopped"
    elif [[ $action == "restart" ]]; then
        docker restart $name$i
        echo "Container $name$i restarted"
    elif [[ $action == "rm" ]]; then
        docker kill $name$i 2> /dev/null
        docker rm $name$i 2> /dev/null
        echo "Container $name$i removed"
    elif [[ $action == "create" ]]; then
        docker create --name $name$i --ip $ip$i -v logs:/var/log/gll --network $network -e CONTAINER_NAME=$name$i -ti $image
        echo "Container $name$i created"
    elif [[ $action == "recreate" ]]; then
        docker kill $name$i 2> /dev/null
        docker rm $name$i 2> /dev/null
        docker run --name $name$i --ip $ip$i -v logs:/var/log/gll --network $network -e CONTAINER_NAME=$name$i -tid $image > /dev/null
        echo "Container $name$i recreated"
    elif [[ $action == "run" ]]; then
        docker kill $name$i 2> /dev/null
        docker rm $name$i 2> /dev/null
        docker run --name $name$i --ip $ip$i -v logs:/var/log/gll --network $network -e CONTAINER_NAME=$name$i -tid $image > /dev/null
        echo "Container $name$i created and running"
    elif [[ $action == "exec" ]]; then
        docker exec -d $name$i bash -c "$exec_command"
        echo "Command $exec_command injected in container $name$i"
    elif [[ $action == "gen" ]]; then
        docker exec -d $name$i bash -c "./genlog.sh $log_number $logs_per_second $log_size"
        echo "Generating logs in container $name$i"
    fi
done
if [[ $action == "gen" ]]; then
    echo "Estimated duration: " $(formatDuration $(($log_number / $logs_per_second)))
fi
if [[ $action == "run" || $action == "create" ]]; then
    docker ps
fi
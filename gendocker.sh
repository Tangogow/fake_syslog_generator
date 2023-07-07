#!/bin/bash

# Parsing Args
action=$1
rangeMin=$2
rangeMax=$3
logNumber=$4
logPerSecond=$5
logSize=$6

ip="172.0.0."
name="gll"
image="gll"
network="gll"
eventApp="MyApp" 
volume="/var/lib/docker/volumes/logs/_data"

usage () {
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
    execCommand=$4
    logNumber=""
fi

if [[ -z $rangeMax ]]; then
    rangeMax=$rangeMin
fi
if [[ $rangeMin -lt 1 || $rangeMax -lt 1 ]]; then
    echo "Wrong range. Need postive integers"
    usage
elif [[ $rangeMin -gt $rangeMax ]]; then
    echo "Wrong range. Rangemax should be higher than rangemin"
    usage
fi
if [[ $action == "gen" ]]; then
    if [[ $logNumber -lt 1 || $logPerSecond -lt 1 || $logSize -lt 1 ]]; then
        echo "Wrong number of logs and/or logs per second and/or size. Need postive integers"
        usage
    fi
fi

logsGenerated=0
realLogsPerSecond=0
totalSizeBytes=0
durationSecs=0

formatDuration () {
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

formatSize () {
    totalSize=$1
    if [[ $totalSize -lt 1024 ]]; then
        echo "$totalSize B"
    elif [[ $totalSize -lt 1048576 ]]; then
        totalSize=$(round $totalSize/1024)
        echo "$totalSize KB"
    elif [[ $totalSize -lt 1073741824 ]]; then
        totalSize=$(round $totalSize/1048576)
        echo "$totalSize MB"
    else
        totalSize=$(round $totalSize/1073741824)
        echo "$totalSize GB"
    fi
}

round () {
    printf "%.0f" $1
}

if [[ $action == "gen" ]]; then
    rm -f $volume/*
elif [[ $action == "logs" ]]; then
    while [[ $(ls -1 $volume | wc -l) -ne $((rangeMax - rangeMin + 1)) ]]; do
        echo "Waiting for logs... Logs present: $(ls -1 $volume | wc -l)"
        sleep 1
    done
    for file in $(ls $volume); do
        while IFS=',' read -ra values; do
            if [[ ${#values[@]} -eq 4 ]]; then
                logsGenerated=$((logsGenerated + values[0]))
                realLogsPerSecond=$((realLogsPerSecond + values[1]))
                totalSizeBytes=$((totalSizeBytes + values[2]))
                if [[ values[3] -gt $durationSecs ]]; then
                    durationSecs=${values[3]}
                fi
            fi
        done < "$file"
    done
    echo "=== FAKE LOG REPORT ==="
    echo "Number container   $(ls -1 $volume | wc -l)"
    echo "Logs generated     $logsGenerated"
    echo "Logs/s             $realLogsPerSecond"
    echo "Total size         $(formatSize $totalSizeBytes)"
    echo "Duration           $(formatDuration $durationSecs)"
    exit 0
fi

for (( i=rangeMin; i<=rangeMax; i++ )); do
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
        docker create --name $name$i --ip $ip$i -v logs:/logs --network $network -e NAME=$name$i -ti $image
        echo "Container $name$i created"
    elif [[ $action == "recreate" ]]; then
        docker kill $name$i 2> /dev/null
        docker rm $name$i 2> /dev/null
        docker run --name $name$i --ip $ip$i -v logs:/logs --network $network -e NAME=$name$i -tid $image
        echo "Container $name$i recreated"
    elif [[ $action == "run" ]]; then
        docker kill $name$i 2> /dev/null
        docker rm $name$i 2> /dev/null
        docker run --name $name$i --ip $ip$i -v logs:/logs --network $network -e NAME=$name$i -tid $image
        echo "Container $name$i created and running"
    elif [[ $action == "exec" ]]; then
        docker exec -d $name$i bash -c "$execCommand"
        echo "Command $execCommand injected in container $name$i"
    elif [[ $action == "gen" ]]; then
        docker exec -d $name$i bash -c "./genlog.sh $eventApp $logNumber $logPerSecond $logSize"
        echo "Generating logs in container $name$i"
    fi
done
if [[ $action == "run" || $action == "create" ]]; then
    docker ps
fi
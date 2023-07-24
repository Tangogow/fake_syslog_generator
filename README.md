# Fake Syslog Generator

Generate logs to benchmark the performance of your SIEM or your network and infrastructure bandwidth with Linux logs as traffic.

*If you want to know how many requests your system and network can handle before your SIEM goes slow ?* Let's launch 10.000 linux containers and generate 100MB of logs every minute on each, and find out !

# Description

This tool's purpose is to stress test, SIEM, IDS, SOAR in terms of performance by the number and size of logs, __not to trigger any detection__. (most of the generated logs are either random logs or random bytes)

This tool uses Docker container to simulate a large number of machines with their own IP and generate fake logs which are retrieved by any SIEM/IDS with the pulling method, on the container directly or retrieved from a Syslog server.
The container does not send the logs, you'll have to configure your SIEM to pull the syslogs on port 514 or to pull the Syslog Server.

Another purpose is to benchmark your network and/or your on premise infrastructure, and see if your bandwidth is sufficient enough to handle heavy loads.

If you want only to generate random logs on a single machine, the `genlog.sh` script can be used independently.

*This tool is originally intended to be launched from a high performance server in your target network, but you can launch it simultaneously on multiple servers. Only condition is not to use the same container number, example:*
- first host: `./gendocker.sh run 1 100`
- second host: `./gendocker.sh run 101 200`

# How it work

1. A control script called `gendocker.sh` will act as a command and control script: it will manage all the containers like creation, running, deleting, executing commands and generating logs for all the containers. It act like a wrapper around the docker command.
2. When the containers are launched, the `genlog.sh` script will be copied in /home/debian. 
3. The `gendocker.sh gen` command will trigger the `genlog.sh` script in all containers to generate logs. The logs consist of a "FAKE" tag and hostname name (IP can be included also), then followed with random bytes until the defined log size is reached in the container `/var/log/messages`. **The script `genlog.sh` can be run individually and manually on any machine**
4. Once finished, a csv with the results is generated in the `/var/log/gll` folder inside the container, which is a binded volume, which path is defined in the `$volume` variable in `gendocker.sh`.
4. To check the status of the current log generation, use `gendocker logs`. It will display the result once the log generation is completed in all the containers. This command can also be used after the log generation. It aggregates all the generated logs csv present in the binded volume. *A new "gen" will erase all the existing results.*
5. You can also forward all the generated logs to a Syslog server, which needs to be accessible from the Docker host.

# How to start

1. If you haven't Docker, install it from [here](https://docs.docker.com/engine/install/debian/)
2. On your Docker host, create a Docker network with `docker network create  --subnet 172.0.0.0/16 --gateway 172.0.255.254 --label gll --driver bridge gll` *(the Docker bridge act like a bridge and a NAT at the same time)*
3. Build the image with `docker build -t gll .`
4. (Optional) If you want to forward all your generated logs to a Syslog server (which can be either the Docker host itself or another reachable host), configure your Linux Syslog server IP in the `$syslog_server` variable in `gendocker.sh` then execute the following commands on your syslog server:
```bash
apt update && apt install rsyslog
echo -e "if \$fromhost-ip startswith '172.0.' then /var/log/gll.log\n& stop" > /etc/rsyslog.d/01-gll.conf
sudo sed -i 's/^#\$ModLoad imtcp/\$ModLoad imtcp/' /etc/rsyslog.conf
sudo sed -i 's/^#\$InputTCPServerRun 514/\$InputTCPServerRun 514/' /etc/rsyslog.conf
systemctl enable rsyslog && systemctl start rsyslog
```
5. Launch your Docker cluster with `./gendocker.sh run 1 200` (for 200 containers from n°1 to n°200)
6. Connect your Syslog server with your SIEM or connect all your containers with your SIEM. Your containers IP start at 172.0.0.1. (by default the number of the container = the last bytes of the IP). *If you're launching more than 255 machines, the IPs will be automatically incremented at 172.0.1.x and so on.*
7. Once all launched, generate some log with `./gendocker.sh gen 1 200 1000 100 5000`. It'll generate 1000 logs with a rate of 100 logs/s with 5KB randoms bytes on 200 containers.
8. Wait for the result to come with `./gendocker.sh logs 1 200`
9. If you've a Syslog server, logs will be forwarded to `/var/log/gll.log`


You can attach a tty to any individual container with `docker attach gll<number>` and launch inside `./genlog.sh 100 100 100` *(dont use 'exit' to exit the container, you'll kill it)*

Once all containers launched, you can regenerate logs at will instantaneously

# Benchmark

Depending on the machine, the number of logs per second may vary from what you wished for. Usually, logger can only output on average 70 syslogs per seconds on Debian11

Benchmark done with 1000 logs on each container at the rate 100 logs/s with 10KB of logs, on a 127vCPU 256GB RAM machine.

| Number of containers | 10 | 100 | 1000 | 10000 | Average |
| :-: | :-: | :-: | :-: | :-: | :-: |
| Create and run container | 10sec | 1min20 | 14min | 2h30 | 0,8 container/sec |
| Generate log | 2sec | 20sec | 5 mins | 50mins | 0,3 container log/sec |
| Eetrieve log | 12sec | 50sec | 6 mins | 1h | 0,4 logs/sec |
| Total size | 10MB | 100MB | 1GB | 10GB | 10KB/logs * 1000 logs/container |

*Retrieve log duration include the generate log duration*

The number of logs on each container doesn't impact much, rather the number of containers.

You'll generate way faster load with  higher load of log and a lower number of containers than a high number of container with very low load of logs.

# Limitation

They are several limitation.

You might be bottlenecked at different place:
1. Your machine (CPU, OS and disk IO's)
2. Your bandwidth (switchs, routers, cables, network cards, adapters)
3. Your software (SIEM, IDS, Databases)

# Hardware

A server with 128 vCPU and 250GB of RAM will allow you to simulate:
- 2.000 or more Linux Debian containers

# Dependecies

- Docker with Debian image

# Issues

* May have issues with different syslog format or date locale format.
Used locale is `US_us` and default syslog format is `%b %d %H:%M:%S`

* Docker-compose performance are quite the same (with the scale option) and doesn't offer native functionality to perform this kind of task, but could be a more sustainable way to perform than a bash script.

* Due to the technical limitations of Docker, it is impossible to efficiently thread (in C or Python) the `docker exec` command used for the `gen`, as well as the `docker run` command used for the `run`
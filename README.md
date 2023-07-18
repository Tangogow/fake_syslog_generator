# Fake Syslog Generator

Generate logs to benchmark the performance of your SIEM or IDS.

*If you want to know how many requests your system and network can handle before your SIEM goes slow ?* Let's launch 10.000 linux containers and generate 100MB of logs every minute on each, and find out !

# Description

This tool's purpose is to stress test, SIEM, IDS, SOAR in terms of performance by the number and size of logs, not to trigger any detection. (most of the generated logs are either random logs or random bytes)

This tool uses Docker container to simulate a large number of machines with their own IP and generate fake logs which are retrieved by any SIEM/IDS with the pulling method. 
The container does not send the logs, you'll to configure your SIEM to pull the syslogs on port 514.

Another purpose is to benchmark your network and/or your on premise infrastructure, and see if your bandwidth is sufficient enough to handle heavy loads.

*This tool is originally intended to be launched from a high capacity server, but you can launch it simultanously on multiple servers. Only condition is not to use the same container number, example:*
- first host: `./gendocker.sh run 1 100`
- second host: `./gendocker.sh run 101 200`

# How to start

1. Create Docker network with `docker network create --gateway 172.0.255.254 --label gll --subnet 172.0.0.0/16 gll`
2. Build the image with `docker build -t gll .`
3. Launch your Docker cluster with `./gendocker.sh run 1 20` (for 20 container from n°1 to n°20). It take around half a second to launch one container.
4. Connect all your containers with your SIEM. Your containers IP start at 172.0.0.1. (by default the number of the container = the last bytes of the IP). If you're launching more than 255 machines, the IPs will be automaticly incremented at 172.0.1.x and so on.
5. Once all launched, generate some log with `./gendocker.sh gen 1 20 1000 100 50`. It'll generate 1000 logs with a rate of 100 logs/s with a size of 50 randoms bytes on 20 containers.
6. Wait for the result to come with `./gendocker.sh logs 1 20`


You can attach a tty to any individual container with `docker attach gll<number>` and launch inside `./genlog.sh 100 100 100` *(dont use 'exit' to exit the container, you'll kill it)*

Once all container launched, you can regenerate logs at will instantaneously

Depending on the machine, the number of logs per second may vary from what you wished for. Usually, logger can only output on average 70 syslogs per seconds.

# Benchmark

Benchmark with 1000 logs on each container at the rate 100 logs/s with 10KB of logs, on a 127vCPU 256GB RAM machine.

The number of logs on each container doesn't impact much, rather the number of container.

You'll generate way more faster load with a high load of log and a low number of container than a high number of container with very low load of logs.

| Number of containers | 10 | 100 | 1000 | 10000 | Average |
| :-: | :-: | :-: | :-: | :-: | :-: |
| Create and run container | 10sec | 1min20 | 14min | 2h30 | 0,8 container/sec |
| Generate log | 2sec | 20sec | 5 mins | 50mins | 0,3 container log/sec |
| Eetrieve log | 12sec | 50sec | 6 mins | 1h | 0,4 logs/sec |
| Total size | 10MB | 100MB | 1GB | 10GB | 10KB/logs * 1000 logs/container |

*Retrieve log duration include the generate log duration*

# Limitation

They are several limitation.

You might be bottlenecked at different place:
1. Your machine (CPU, OS and disk IO's)
2. Your bandwith (switch, router, cables, network cards)
3. Your software (SIEM, IDS, Database)

# Hardware

A server with 128 vCPU and 250GB of RAM will allow you to simulate:
- 20.000 Linux Debian containers

# Dependecies

- Docker

# Issues

* May have issues with different syslog format or date locale format.
Used locale is `US_us` and default syslog format is `%b %d %H:%M:%S`

* Docker-compose performance are quite the same (with the scale option) and doesn't offer native functionnality to perform this kind of task, but could be a more sustainable way to perform.

* Due to the technical limitations of Docker, it is impossible to efficiently thread (in C or Python) the `docker exec` command used for the `gen`, as well as the `docker run` command used for the `run`
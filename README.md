# Fake Syslog Generator

Generate logs to benchmark the performance of your SIEM or IDS.

*If you want to know how many requests your system and network can handle before your SIEM goes slow ?* Let's launch 10.000 linux container and generate 100MB of logs every minute on each, and find out !

# Description

This tool's purpose is to stress test, SIEM, IDS, SOAR in terms of performance by the number and size of logs, not to trigger any detection. (most of the generated logs are either random logs or random bytes)

This tool uses Docker container to simulate a large number of machines with their own IP and generate fake logs which are retrieved by any SIEM/IDS with the pulling method. 
The container does not send the logs, it's the SIEM who's pulling it on port 514.

Another purpose is to benchmark your network and/or your on premise infrastructure, and see if your bandwidth is sufficient enough to handle heavy loads.

*This tool is originally intended to launched from a high capacity server.*

# How to start

1. Configure the number of logs, logs per second (minimum 1) and logs size (in bytes) in the Dockerfile
2. Create Docker network with `docker network create --gateway 172.0.255.254 --label gll --subnet 172.0.0.0/16`
2. Build the image with `docker build -t gll .`
3. Launch your Docker cluster with
3. Connect all your containers with your SIEM
4. You can attach a tty to any individual container with `docker attach gll1`

# Limitation

They are several limitation.

You might be bottlenecked at different place:
1. Your machine (CPU, OS and disk IO's)
2. Your bandwith (switch, router, cables, network cards)
3. Your software (SIEM, IDS, Database)

# Hardware

A server with 128 vCPU and 250GB of RAM will allow you to simulate either:
- 20.000 Linux Debian containers

# Dependecies

- Docker

# Issues

May have issues with different syslog format or date locale format.
Used locale is `US_us` and default syslog format is `%b %d %H:%M:%S` 
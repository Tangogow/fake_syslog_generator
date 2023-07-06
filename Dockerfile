FROM debian:latest

EXPOSE 514

COPY "load\*" "/home/debian"
WORKDIR "/home/debian"
#RUN "./genlog.sh 1000 10 100"
ENTRYPOINT ["/bin/bash"]
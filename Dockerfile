FROM debian:latest

EXPOSE 514

COPY "load" "/home/debian"
WORKDIR "/home/debian"
RUN apt update && \
apt install -y rsyslog; \
service rsyslog start; \
touch /var/log/messages; \
logger -f /var/log/messages; \
chmod +x genlog.sh

#RUN "./genlog.sh 1000 10 100"
ENTRYPOINT ["/bin/bash"]
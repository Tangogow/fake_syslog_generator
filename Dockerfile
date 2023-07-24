FROM debian:latest

EXPOSE 514

WORKDIR /home/debian

COPY genlog.sh /home/debian

RUN apt update && apt install -y rsyslog
RUN chmod +x /home/debian/genlog.sh
RUN service rsyslog start || rsyslogd

ENTRYPOINT ["/bin/bash"]
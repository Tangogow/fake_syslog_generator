FROM debian:latest

EXPOSE 514

COPY "load" "/home/debian"
WORKDIR "/home/debian"
RUN apt update && apt install -y rsyslog
RUN chmod +x /home/debian/genlog.sh
RUN service rsyslog start || rsyslogd

#RUN "./genlog.sh 1000 10 100"
ENTRYPOINT ["/bin/bash"]
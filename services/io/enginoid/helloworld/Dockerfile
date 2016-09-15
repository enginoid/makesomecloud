FROM anapsix/alpine-java:8_server-jre
EXPOSE 8080

ADD server.jar /service/bin/server.jar
RUN mkdir -p /service/log

CMD java -jar /service/bin/server.jar -log.dir=/service/log

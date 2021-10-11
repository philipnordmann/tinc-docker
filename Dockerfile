FROM alpine:3
RUN apk update && apk upgrade
RUN apk add tinc expect

RUN mkdir -p /opt/tincd/
COPY entrypoint.sh /opt/tincd/

VOLUME [ "/config" ]
EXPOSE 655/tcp 655/udp

ENTRYPOINT [ "/bin/sh", "/opt/tincd/entrypoint.sh" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD netstat -anp | grep -q 655
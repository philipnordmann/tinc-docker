FROM alpine:3.12
RUN apk update && apk upgrade
RUN apk add tinc python3 python3-dev py3-pip git
RUN pip3 install pip --upgrade
RUN mkdir -p /opt/tincd/git

COPY requirements.txt /opt/tincd/
RUN pip3 install -r /opt/tincd/requirements.txt

COPY *.py *.sh /opt/tincd/

VOLUME [ "/config" ]
EXPOSE 655/tcp 655/udp

ENTRYPOINT [ "/bin/sh", "/opt/tincd/entrypoint.sh" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD netstat -anp | grep -q 655
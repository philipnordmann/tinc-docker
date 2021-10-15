FROM alpine:3
RUN apk update && apk upgrade
RUN apk add tinc expect gcc python3 python3-dev musl-dev libffi-dev py3-pip git

RUN mkdir -p /opt/tincd/
COPY *.py *.txt *.sh /opt/tincd/

RUN pip3 install pip --upgrade
RUN pip3 install -r /opt/tincd/requirements.txt

VOLUME [ "/config" ]
EXPOSE 655/tcp 655/udp

ENTRYPOINT [ "/bin/sh", "/opt/tincd/entrypoint.sh" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD netstat -anp | grep -q 655
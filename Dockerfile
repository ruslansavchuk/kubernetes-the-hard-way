FROM ubuntu:22.04

RUN apt update \
    && apt install -y wget systemd kmod systemd-sysv \
    && rm -rf /var/lib/apt/lists/* 

RUN systemctl set-default multi-user.target

RUN find /etc/systemd/system /lib/systemd/system \
    -path '*.wants/*' -not -name '*systemd*' -exec rm -f {} \;

ENTRYPOINT ["/lib/systemd/systemd", "--system"]
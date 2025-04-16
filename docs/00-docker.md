# Build container image

Create dockerfile for the container

```bash
cat <<EOF | tee Dockerfile
FROM ubuntu:22.04

RUN apt update \
    && apt install -y wget systemd kmod systemd-sysv vim less iptables \
    && rm -rf /var/lib/apt/lists/*

RUN systemctl set-default multi-user.target

RUN find /etc/systemd/system /lib/systemd/system \
    -path '*.wants/*' -not -name '*systemd*' -exec rm -f {} \;

CMD mkdir /workdir
WORKDIR /workdir

ENTRYPOINT ["/lib/systemd/systemd", "--system"]
EOF
```

Build container image

```bash
docker build -t ubuntu-systemd .
```

Run created container image

```bash
docker run -d \
  --name ubuntu-systemd-container \
  --privileged \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  ubuntu-systemd
```

And now we need to run bash inside container

```bash
docker exec -it ubuntu-systemd-container bash
```

Next: [Kubernetes architecture](./00-kubernetes-architecture.md)
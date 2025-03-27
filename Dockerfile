FROM ubuntu:22.04

# Update package list and install systemd
# RUN apt-get update && apt-get install -y systemd && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y systemd kmod systemd-sysv && rm -rf /var/lib/apt/lists/*

# Configure systemd (optional: set default target)
RUN systemctl set-default multi-user.target

# Remove unnecessary systemd units to speed up boot (optional)
RUN find /etc/systemd/system /lib/systemd/system \
    -path '*.wants/*' -not -name '*systemd*' -exec rm -f {} \;

# Set systemd as the entrypoint
ENTRYPOINT ["/lib/systemd/systemd", "--system"]
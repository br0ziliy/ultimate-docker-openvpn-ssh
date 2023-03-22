FROM alpine:latest

LABEL maintainer="Vasyl Kaigorodov <vkaygorodov@gmail.com>"
LABEL version="latest"
LABEL description="Ultimate Docker container with OpenVPN client and SSH daemon"

RUN apk add --update bash openvpn openssh openssh-keygen bind-tools curl && \
    adduser tunnel -D && \
    mkdir /vpn_configs && \
    mkdir /root/.ssh && \
    chmod 0700 /root/.ssh && \
    passwd -u tunnel && \
    mkdir -p /etc/authorized_keys && \
    ssh-keygen -t ed25519 -f /ssh_host_ed25519_key -N "" < /dev/null && \
    chmod 400 /ssh_host_ed25519_key && \
    rm -rf /var/cache/apk/*

COPY openvpn-ssh.sh /openvpn-ssh.sh
COPY sshd_config /sshd_config
COPY authorized_keys /etc/authorized_keys/tunnel

EXPOSE 22
ENV DVPN_CONFIG "default"
ENV DVPN_DEBUG ""
ENTRYPOINT ["bash", "/openvpn-ssh.sh"]

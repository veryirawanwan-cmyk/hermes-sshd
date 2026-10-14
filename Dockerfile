# Railway-friendly SSH + ttyd + hermes bootstrap image
# Mirip image railway-ubuntu-sshd tapi pny sendiri: Ubuntu + SSH + ttyd + hermes auto-start
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# Install deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    curl \
    ca-certificates \
    git \
    sudo \
    tmux \
    ttyd \
    python3 \
    python3-pip \
    nodejs \
    npm \
    htop \
    && rm -rf /var/lib/apt/lists/*

# SSH setup
RUN mkdir -p /run/sshd /root/.ssh \
    && echo 'root:Rw17906835624263' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo 'export PATH=$PATH:/root/.local/bin' >> /root/.bashrc

# hermes-gw startup script
COPY scripts/hermes-gw.sh /root/hermes-gw.sh
RUN chmod +x /root/hermes-gw.sh

# expose ports
EXPOSE 22 7681

# entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

FROM ubuntu:latest

EXPOSE 8555
EXPOSE 8444

ENV CHIA_ROOT=/home/docker/.chia/mainnet
ENV keys="generate"
ENV harvester="false"
ENV farmer="false"
ENV plots_dir="/plots"
ENV farmer_address="null"
ENV farmer_port="null"
ENV testnet="false"
ENV TZ="UTC"
ENV upnp="true"
ENV log_to_file="true"

# Remove these two COPY commands
# Was needed due to Windows Insider Preview expiration issue https://github.com/microsoft/WSL/issues/6509
COPY 01-disable-security-check /etc/apt/apt.conf.d/
COPY pip.conf /etc/pip.conf

RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y bc curl lsb-release python3 tar bash ca-certificates git openssl unzip wget python3-pip sudo acl build-essential python3-dev python3.8-venv python3.8-distutils python-is-python3 vim tzdata libxss1 libglib2.0-0 libnss3-tools libatk1.0-0 libatk-bridge2.0-0 libx11-xcb1 libgdk-pixbuf2.0-0 libgtk-3-0 libdrm2 libgbm1 xterm && \
    echo 'docker ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    useradd -m -u 1000 -g 100 docker && echo "docker:docker" | chpasswd && adduser docker sudo

ARG BRANCH=latest
ARG TZ="UTC"

USER docker
WORKDIR /home/docker

RUN echo "cloning ${BRANCH}" && \
    git clone --recursive --branch ${BRANCH} https://github.com/Chia-Network/chia-blockchain.git && \
    cd chia-blockchain && \
    sed -i "s/sudo apt-get install -y npm nodejs libxss1/true/" install-gui.sh && \
    /usr/bin/sh ./install.sh && \
    . ./activate && \
    /usr/bin/sh ./install-timelord.sh && \
    /usr/bin/sh ./install-gui.sh && \
    sed -i "s/electron \./electron --no-sandbox \./" chia-blockchain-gui/packages/wallet/package.json && \
    sudo chown root chia-blockchain-gui/packages/wallet/node_modules/electron/dist/chrome-sandbox && \
    sudo chmod 4755 chia-blockchain-gui/packages/wallet/node_modules/electron/dist/chrome-sandbox && \ 
    sudo sed -i '$ d' /etc/sudoers

ENV PATH=/home/docker/chia-blockchain/venv/bin:$PATH
WORKDIR /home/docker/chia-blockchain

COPY docker-start.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["docker-start.sh"]

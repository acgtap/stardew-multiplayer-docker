# Pull base image.
FROM jlesage/baseimage-gui:debian-11

# Set the name of the application.
ENV APP_NAME="StardewValley"

# Support both regular Docker and Pterodactyl deployments
# Configure s6-overlay to use writable directories for Pterodactyl compatibility
ENV SERVER_DIR="/home/container" \
    CONFIG_DIR="/config" \
    S6_RUNTIME_DIR="/tmp/s6-runtime" \
    S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_LOGGING=0 \
    S6_KEEP_ENV=1

RUN apt-get update
RUN apt-get install -y wget unzip tar strace mono-complete xterm gettext-base jq netcat procps xvfb x11vnc 
#RUN APP_ICON_URL=https://stardewcommunitywiki.com/mediawiki/images/4/48/Fiddlehead_Fern.png && \
#    install_app_icon.sh "$APP_ICON_URL"

# Game + ModLoader 1.5.6 3.18.2
RUN mkdir -p /data/Stardew && \
    mkdir -p /data/nexus && \
    wget https://eris.cc/Stardew_1.6.15.tar.gz -qO /data/latest.tar.gz && \
    tar xf /data/latest.tar.gz -C /data/Stardew && \
    rm /data/latest.tar.gz 

RUN wget -qO dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/6788a5a5-1879-4095-948d-72c7fbdf350f/c996151548ec9f24d553817db64c3577/dotnet-sdk-5.0.402-linux-x64.tar.gz \
    #RUN wget -qO dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/95352809-7f41-40f3-974d-8d530321a8e4/0024d7bf0c872f176ceba7a63a34915b/dotnet-runtime-6.0.0-linux-musl-x64.tar.gz \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet 

RUN wget https://github.com/Pathoschild/SMAPI/releases/download/4.1.10/SMAPI-4.1.10-installer.zip -qO /data/nexus.zip && \
    unzip /data/nexus.zip -d /data/nexus/ && \
    /bin/bash -c "SMAPI_NO_TERMINAL=true SMAPI_USE_CURRENT_SHELL=true echo -e \"2\n\n\" | /data/nexus/SMAPI\ 4.1.10\ installer/internal/linux/SMAPI.Installer --install --game-path \"/data/Stardew/Stardew Valley\"" || :

# Add Mods & Scripts
COPY ["mods/", "/data/Stardew/Stardew Valley/Mods/"]
COPY scripts/ /opt/

RUN chmod +x /data/Stardew/Stardew\ Valley/StardewValley && \
    chmod -R 777 /data/Stardew/ && \
    chown -R 1000:1000 /data/Stardew && \
    chmod +x /opt/*.sh && \
    mkdir -p /home/container && \
    chmod -R 777 /home/container && \
    mkdir -p /tmp/s6-runtime /tmp/.X11-unix && \
    chmod -R 777 /tmp/s6-runtime /tmp/.X11-unix && \
    mkdir -p /var/run && \
    chmod 777 /var/run && \
    rm -rf /var/run/s6 && \
    ln -sf /tmp/s6-runtime /var/run/s6 && \
    mkdir -p /tmp/s6-runtime/env-stage1 && \
    chmod -R 777 /tmp/s6-runtime && \
    mkdir -p /etc/s6/init/env && \
    chmod -R 777 /etc/s6/init

RUN mkdir /etc/services.d/utils && touch /etc/services.d/app/utils.dep
COPY run /etc/services.d/utils/run 
RUN chmod +x /etc/services.d/utils/run 

COPY docker-entrypoint.sh /startapp.sh

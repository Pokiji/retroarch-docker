FROM ubuntu:22.04

# User and environment settings
ENV USER=root
ENV PASSWORD=password1

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV XKB_DEFAULT_RULES=base

# Install dependencies
RUN apt-get update && \
    echo "tzdata tzdata/Areas select America" > /tmp/tx.txt && \
    echo "tzdata tzdata/Zones/America select New_York" >> /tmp/tx.txt && \
    debconf-set-selections /tmp/tx.txt && \
    apt-get install -y --no-install-recommends \
        unzip gnupg apt-transport-https wget software-properties-common \
        ratpoison novnc websockify libxv1 libglu1-mesa xauth x11-utils \
        xorg tightvncserver libegl1-mesa x11-xkb-utils bzip2 \
        gstreamer1.0-plugins-good gstreamer1.0-pulseaudio gstreamer1.0-tools \
        libgtk2.0-0 libncursesw5 libopenal1 libsdl-image1.2 libsdl-ttf2.0-0 \
        libsdl1.2debian libsndfile1 nginx pulseaudio supervisor ucspi-tcp \
        build-essential ccache && \
    rm -rf /var/lib/apt/lists/*

# Add RetroArch PPA and install RetroArch
RUN add-apt-repository -y ppa:libretro/stable && \
    apt-get update && \
    apt-get install -y retroarch && \
    rm -rf /var/lib/apt/lists/*

# Copy PulseAudio and NGINX config files
COPY default.pa client.conf /etc/pulse/
COPY nginx.conf /etc/nginx/
COPY webaudio.js /usr/share/novnc/core/

# Inject WebAudio code into NoVNC client UI
RUN sed -i "/import RFB/a \\
      import WebAudio from '/core/webaudio.js'" /usr/share/novnc/app/ui.js && \
    sed -i "/UI.rfb.resizeSession/a \\
        var loc = window.location, new_uri; \\
        if (loc.protocol === 'https:') { \\
            new_uri = 'wss:'; \\
        } else { \\
            new_uri = 'ws:'; \\
        } \\
        new_uri += '//' + loc.host; \\
        new_uri += '/audio'; \\
      var wa = new WebAudio(new_uri); \\
      document.addEventListener('keydown', e => { wa.start(); });" /usr/share/novnc/app/ui.js


# Setup VNC password and config files
RUN mkdir -p ~/.vnc ~/.dosbox && \
    echo "$PASSWORD" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 0600 ~/.vnc/passwd && \
    echo "set border 1" > ~/.ratpoisonrc && \
    echo "exec retroarch" >> ~/.ratpoisonrc && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout ~/novnc.pem -out ~/novnc.pem -days 3650 \
        -subj "/C=US/ST=NY/L=NY/O=NY/OU=NY/CN=NY/emailAddress=email@example.com"

# Expose HTTP port for NoVNC/web interface
EXPOSE 80

# Create ROMs directory
RUN mkdir /roms

# Copy RetroArch config and supervisor config
COPY retroarch.cfg /root/.config/retroarch/retroarch.cfg
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Start supervisord to manage services
ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

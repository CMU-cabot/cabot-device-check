FROM ubuntu:focal

ENV DEBIAN_FRONTEND="noninteractive" \
    UBUNTU_DISTRO=focal    

RUN apt update && \
	apt install -y --no-install-recommends \
	gnupg gnupg1 gnupg2 \
	software-properties-common \
	&& \
	apt clean && \
	rm -rf /var/lib/apt/lists/*
RUN apt-key adv --keyserver keys.gnupg.net --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE || \
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE && \
	add-apt-repository "deb https://librealsense.intel.com/Debian/apt-repo $UBUNTU_DISTRO main" -u
RUN apt update && \
	apt install -y --no-install-recommends \
	arp-scan \
	gettext \
	librealsense2-utils \
	network-manager \
	pciutils \
	python3 \
	python3-pip \
	python-is-python3 \
	usbutils \
	&& \
	apt clean && \
	rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir \
	odrive==0.5.2.post0

RUN apt update && \
	apt install -y --no-install-recommends \
	locales \
	&& \
	apt clean && \
	rm -rf /var/lib/apt/lists/*
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

FROM ubuntu:18.04

LABEL MAINTAINER=DongsuPark<dongsu2005@naver.com>

ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive # Allows apt-get install to be used without interaction

RUN apt-get update && apt-get install -y apt-utils && \
    apt-get install -y vim tzdata wget mysql-client ssh libreadline-dev curl git \
    ca-certificates sudo locales language-pack-ko
RUN apt-get install -y g++ make libmysqlclient-dev ruby ruby-dev python3-pip lftp openjdk-8-jdk nkf \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen ko_KR.UTF-8
ENV LC_ALL ko_KR.UTF-8

RUN useradd -m -s /bin/bash docker && \
    usermod -G users docker && \
    usermod -G users root && \
    echo '%users ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    echo "Set disable_coredump false" >> /etc/sudo.conf && \
    mkdir /home/docker/.ssh && chown docker.docker /home/docker/.ssh

RUN mkdir /var/run/sshd && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

RUN wget -q "https://github.com/embulk/embulk/releases/download/v0.10.1/embulk-0.10.1.jar" -O /usr/local/bin/embulk
RUN chmod +x /usr/local/bin/embulk

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jdk/bin/java 

# install embulk module
RUN embulk gem install embulk-output-postgresql embulk-input-postgresql 
RUN embulk gem install embulk-output-sqlserver embulk-input-sqlserver

CMD ["/bin/bash"]
    

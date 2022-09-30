FROM jenkins/inbound-agent:alpine as jnlp

FROM jenkins/agent:latest-jdk11

ARG version
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

ARG user=jenkins

USER root

COPY --from=jnlp /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-agent

RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    rsync \
    wget \
    gradle \
    maven

# Dependencies to execute Android builds
RUN apt-get update -qq
RUN dpkg --add-architecture i386 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openjdk-11-jdk \
    libc6:i386 \
    libgcc1:i386 \
    libncurses5:i386 \
    libstdc++6:i386 \
    libz1:i386

SHELL ["/bin/bash", "-c"]

ENV ANDROID_HOME /opt/sdk
ENV ANDROID_SDK_ROOT /opt/sdk

RUN mkdir -p ${ANDROID_SDK_ROOT}
RUN cd ${ANDROID_SDK_ROOT} && wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip -O sdk-tools.zip
RUN cd ${ANDROID_SDK_ROOT} && mkdir tmp && unzip sdk-tools.zip -d tmp && rm sdk-tools.zip
RUN cd ${ANDROID_SDK_ROOT} && mkdir -p cmdline-tools/latest && mv tmp/cmdline-tools/* cmdline-tools/latest

ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --update
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools"
RUN sdkmanager --install "ndk;25.1.8937393" "cmake;3.22.1"

# Please keep all sections in descending order!
# list all platforms, sort them in descending order, take the newest 8 versions and install them
RUN yes | sdkmanager $( sdkmanager  --list 2>/dev/null| grep platforms | awk -F' ' '{print $1}' | sort -nr -k2 -t- | head -4 )
# list all build-tools, sort them in descending order and install them
RUN yes | sdkmanager $( sdkmanager  --list 2>/dev/null| grep build-tools | awk -F' ' '{print $1}' | sort -nr -k2 -t\; | uniq )
RUN yes | sdkmanager \
    "platforms;android-32" \
    "platforms;android-31" \
    "platforms;android-30" \
    "build-tools;30.0.3" \
    "extras;android;m2repository" \
    "extras;google;m2repository"

USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]

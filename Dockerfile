FROM quay.io/bitriseio/bitrise-base:alpha

ENV ANDROID_SDK_ROOT /opt/android
ENV ANDROID_HOME /opt/android-sdk-linux
ENV ANDROID_NDK_VERSION r20
ENV ANDROID_HOME=${ANDROID_SDK_ROOT}
ENV ANDROID_SDK_HOME=${ANDROID_SDK_ROOT}
ENV ANDROID_NDK_HOME /opt/android-ndk
ENV GRADLE_VERSION=6.3
ENV PATH=$PATH:"/opt/gradle/gradle-${GRADLE_VERSION}/bin/"

# Update the base image with the required components.
RUN mkdir -p /usr/share/man/man1 \
    && apt-get update -qq && apt-get install -qq -y --no-install-recommends \
    apt-transport-https \
    curl \
    nano \
    build-essential \
    file \
    wget \
    tar \
    zip \
    net-tools \
    lib32stdc++6 \
    lib32z1 \
    git \
    gnupg2 \
    openjdk-8-jdk \
    python \
    openssh-client \
    gradle \
    unzip \
    optipng \
    imagemagick \
    python2 \
    python2.7 \
    python-pip -y \
    && apt-get upgrade -y \
    && apt-get clean

# ------------------------------------------------------
# --- Install required tools

RUN add-apt-repository ppa:openjdk-r/ppa
RUN dpkg --add-architecture i386

# Base (non android specific) tools
# -> should be added to bitriseio/docker-bitrise-base

# Dependencies to execute Android builds
RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk openjdk-11-jdk libc6:i386 libstdc++6:i386 libgcc1:i386 libncurses5:i386 libz1:i386 net-tools

# Keystore format has changed since JAVA 8 https://bugs.launchpad.net/ubuntu/+source/openjdk-9/+bug/1743139
RUN mv /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts.old \
    && keytool -importkeystore -destkeystore /etc/ssl/certs/java/cacerts -deststoretype jks -deststorepass changeit -srckeystore /etc/ssl/certs/java/cacerts.old -srcstoretype pkcs12 -srcstorepass changeit \
    && rm /etc/ssl/certs/java/cacerts.old

# Select JAVA 8  as default
RUN sudo update-java-alternatives --jre-headless --set java-1.8.0-openjdk-amd64
RUN sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac

# ------------------------------------------------------
# --- Download Android Command line Tools into $ANDROID_SDK_ROOT

RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O android-commandline-tools.zip \
    && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && unzip -q android-commandline-tools.zip -d /tmp/ \
    && mv /tmp/cmdline-tools/ ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm android-commandline-tools.zip && ls -la ${ANDROID_SDK_ROOT}/cmdline-tools/latest/

ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin

# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
#  sdkmanager --list

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

RUN touch /root/.android/repositories.cfg

# Emulator and Platform tools
RUN yes | sdkmanager "emulator" "platform-tools"

# SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.

RUN yes | sdkmanager --update --channel=3
# Please keep all sections in descending order!
RUN yes | sdkmanager \
    "platforms;android-30" \
    "platforms;android-29" \
    "platforms;android-28" \
    "build-tools;30.0.3" \
    "build-tools;30.0.2" \
    "build-tools;30.0.0" \
    "build-tools;29.0.3" \
    "build-tools;29.0.2" \
    "build-tools;29.0.1" \
    "build-tools;29.0.0" \
    "build-tools;28.0.3" \
    "build-tools;28.0.2" \
    "build-tools;28.0.1" \
    "build-tools;28.0.0" \
    "system-images;android-30;google_apis;x86" \
    "system-images;android-29;google_apis;x86" \
    "system-images;android-28;google_apis;x86_64" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.2" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.1" \
    "add-ons;addon-google_apis-google-23" \
    "add-ons;addon-google_apis-google-22" \
    "add-ons;addon-google_apis-google-21"

# ------------------------------------------------------
# --- Install Gradle from PPA

# Gradle PPA


RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp \
    && unzip -d /opt/gradle /tmp/gradle-*.zip \
    && chmod +775 /opt/gradle \
    && gradle --version \
    && rm -rf /tmp/gradle*

# ------------------------------------------------------
# --- Install Maven 3 from PPA

RUN apt-get purge maven maven2 \
 && apt-get update \
 && apt-get -y install maven \
 && mvn --version

# Reselect JAVA 8  as default
RUN sudo update-java-alternatives --jre-headless --set java-1.8.0-openjdk-amd64
RUN sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# ------------------------------------------------------
# --- Pre-install Ionic and Cordova CLIs

RUN npm install -g npm && npm install -g app-icon yarn react-native-cli expo-cli create-react-app ionic cordova cordova-res @ionic/cli && npm update -g

# -------------------------------------------------------
# Tools to parse apk/aab info in deploy-to-bitrise-io step
ENV APKINFO_TOOLS /opt/apktools
RUN mkdir ${APKINFO_TOOLS}
RUN wget -q https://github.com/google/bundletool/releases/download/1.4.0/bundletool-all-1.4.0.jar -O ${APKINFO_TOOLS}/bundletool.jar
RUN cd /opt \
    && wget -q https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/4.1.1-6503028/aapt2-4.1.1-6503028-linux.jar -O aapt2.jar \
    && unzip -q aapt2.jar aapt2 -d ${APKINFO_TOOLS} \
    && rm aapt2.jar

# -------------------------------------------------------
# Instalação do NDK
RUN mkdir /opt/android-ndk-tmp && \
    cd /opt/android-ndk-tmp && \
    wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip && \
    # uncompress
    unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip && \
    # move to its final location
    mv ./android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
    # remove temp dir
    cd ${ANDROID_NDK_HOME} && \
    rm -rf /opt/android-ndk-tmp

ENV PATH ${PATH}:${ANDROID_NDK_HOME}

# ------------------------------------------------------
# --- Cleanup and rev num

# Cleaning
RUN apt-get clean

EXPOSE 3000 5000 8100 8200 8080 9876 35729 53703 8081 5037 80 19000 19001

VOLUME ["/app"]
WORKDIR /app
CMD ["bash"]
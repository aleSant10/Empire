FROM python:3.11-bookworm

# env base for dotnet wine python
ENV STAGING_KEY=RANDOM DEBIAN_FRONTEND=noninteractive DOTNET_CLI_TELEMETRY_OPTOUT=1 PYTHONOPTIMIZE=1
ARG WINE_PYTHON_VERSION=3.11.6
RUN dpkg --add-architecture i386

# update and add mandatory sw
RUN  apt update \
  && apt upgrade -y \
  && apt install -y --no-install-recommends build-essential wget wine wine32:i386 \
  && rm -rf /var/lib/apt/lists/*

# install pip
RUN pip install --upgrade pip

# set the def shell for ENV & install microsoft sw
SHELL ["/bin/bash", "-c"]
RUN wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt update && \
    apt install -qq -y \
    --no-install-recommends \
    apt-transport-https \
    dotnet-sdk-6.0 \
    libicu-dev \
    powershell \
    python3-dev \
    python3-pip \
    sudo \
    xclip \
    zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /empire

# copy install and run poetry
COPY pyproject.toml poetry.lock /empire/
RUN pip install poetry \
    --disable-pip-version-check && \
    poetry config virtualenvs.create false && \
    poetry install --no-root

COPY . /empire

# sqlite and modules
RUN sed -i 's/use: mysql/use: sqlite/g' empire/server/config.yaml
RUN mkdir -p /usr/local/share/powershell/Modules && \
    cp -r ./empire/server/data/Invoke-Obfuscation /usr/local/share/powershell/Modules
RUN rm -rf /empire/empire/server/data/empire*

# wine embed version
RUN mkdir -p /wine/python
RUN cd /wine/python \
    && wget -q https://www.python.org/ftp/python/${WINE_PYTHON_VERSION}/python-${WINE_PYTHON_VERSION}-embed-win32.zip \
    && unzip python-*.zip \
    && rm -f python-*.zip

# init wine
ENV WINEPREFIX /wine
ENV WINEPATH Z:\\wine\\python\\Scripts;Z:\\wine\\python
ENV PYTHONHASHSEED=1337

# install pip wine
RUN cd /wine/python \
  && rm python*._pth \
  && wget https://bootstrap.pypa.io/get-pip.py

# install wine python sw
RUN wineboot --init
RUN wineboot --restart
RUN cd /wine/python \
    && wine python --version \
    && wine python get-pip.py \
    && wine pip install pyinstaller[encryption]==5.13.2 pyarmor

#RUN echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd && ls)"
ENTRYPOINT ["ps-empire"]
CMD ["server"]

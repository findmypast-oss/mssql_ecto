FROM elixir:1.6.5-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN apt-get install -y make

# --- Set Locale to en_US.UTF-8 ---

RUN apt-get install -y locales

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales && \
    /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# --- MSSQL ODBC INSTALL ---

RUN apt-get update && \
    apt-get -y install curl apt-transport-https gnupg2 && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17

# --- APP INSTALL ---

RUN mix local.hex --force && \
    mix local.rebar --force

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN mix do deps.get, deps.compile

# --- Be able to run wait for it script ---

RUN chmod +x /usr/src/app/wait-for-it.sh

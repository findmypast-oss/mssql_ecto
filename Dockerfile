FROM elixir:1.5

# --- Set Locale to en_US.UTF-8 ---

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y locales

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales && \
    /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# --- MSSQL ODBC INSTALL ---

RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
&& curl https://packages.microsoft.com/config/debian/8/prod.list | tee -a /etc/apt/sources.list.d/mssql-release.list \
&& apt-get update \
&& ACCEPT_EULA=Y apt-get install msodbcsql -y \
&& apt-get install unixodbc-dev -y

# --- APP INSTALL ---

RUN mix local.hex --force && \
    mix local.rebar --force

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN mix do deps.get

# --- Be able to run wait for it script ---

RUN chmod +x /usr/src/app/wait-for-it.sh

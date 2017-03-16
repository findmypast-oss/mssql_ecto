FROM raniemi/elixir:1.4.0_19.2_ubuntu_xenial

# --- MSSQL ODBC INSTALL ---

RUN apt-get update && apt-get install -y --no-install-recommends apt-transport-https

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
&& curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | tee -a /etc/apt/sources.list.d/mssql-release.list \
&& apt-get update \
&& ACCEPT_EULA=Y apt-get install msodbcsql -y \
&& apt-get install unixodbc-dev -y

# --- APP INSTALL ---

RUN mix local.hex --force && \
    mix local.rebar --force

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN mix do deps.get
RUN chmod +x /usr/src/app/wait-for-it.sh 

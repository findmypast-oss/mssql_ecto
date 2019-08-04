# MssqlEcto

[![Build Status](https://travis-ci.org/findmypast-oss/mssql_ecto.svg?branch=master)](https://travis-ci.org/findmypast-oss/mssql_ecto)
[![Coverage Status](https://coveralls.io/repos/github/findmypast-oss/mssql_ecto/badge.svg)](https://coveralls.io/github/findmypast-oss/mssql_ecto)
[![Inline docs](http://inch-ci.org/github/findmypast-oss/mssql_ecto.svg?branch=master)](http://inch-ci.org/github/findmypast-oss/mssql_ecto)
[![Ebert](https://ebertapp.io/github/findmypast-oss/mssql_ecto.svg)](https://ebertapp.io/github/findmypast-oss/mssql_ecto)
[![Hex.pm](https://img.shields.io/hexpm/v/mssql_ecto.svg)](https://hex.pm/packages/mssql_ecto)
[![LICENSE](https://img.shields.io/hexpm/l/mssql_ecto.svg)](https://github.com/findmypast-oss/mssql_ecto/blob/master/docs/LICENSE)

[Ecto](https://github.com/elixir-ecto/ecto) Adapter for
[Mssqlex](https://github.com/findmypast-oss/mssqlex)

## Installation

### Erlang ODBC Application

MssqlEcto requires the
[Erlang ODBC application](http://erlang.org/doc/man/odbc.html) to be installed.
This might require the installation of an additional package depending on how
you have installed Elixir/Erlang (e.g. on Ubuntu
`sudo apt-get install erlang-odbc`).

### Microsoft's ODBC Driver

MssqlEcto depends on Microsoft's ODBC Driver for SQL Server. You can find
installation instructions for
[Linux](https://docs.microsoft.com/en-us/sql/connect/odbc/linux/installing-the-microsoft-odbc-driver-for-sql-server-on-linux)
or
[other platforms](https://docs.microsoft.com/en-us/sql/connect/odbc/microsoft-odbc-driver-for-sql-server)
on the official site.

### Hex

#### With [Application Inference](https://elixir-lang.org/blog/2017/01/05/elixir-v1-4-0-released/#application-inference)

If you are using
[application inference](https://elixir-lang.org/blog/2017/01/05/elixir-v1-4-0-released/#application-inference),
i.e. `application` in your `mix.exs` looks something like this:

```elixir
def application do
  [extra_applications: [:logger]]
end
```

Note, the lack of `:applications` key. Then, you just need to add the following
dependencies:

```elixir
def deps do
  [{:mssql_ecto, "~> 1.2.0"},
   {:mssqlex, "~> 1.1.0"}]
end
```

#### Without [Application Inference](https://elixir-lang.org/blog/2017/01/05/elixir-v1-4-0-released/#application-inference)

If you are explicitly calling out all running applications under `application`
in your `mix.exs`, i.e. it looks something like this:

```elixir
def application do
  [applications: [:logger, :plug, :postgrex]]
end
```

Then, you need to add `mssql_ecto` and `mssqlex` to both your `deps` and list of
running applications:

```elixir
def application do
  [applications: [:logger, :plug, :mssqlex, :mssql_ecto]]
end

def deps do
  [{:mssql_ecto, "~> 1.2.0"},
   {:mssqlex, "~> 1.1.0"}]
end
```

## Configuration

Example configuration:

```elixir
config :my_app, MyApp.Repo,
  adapter: MssqlEcto,
  database: "sql_server_db",
  username: "bob",
  password: "mySecurePa$$word",
  hostname: "localhost",
  instance_name: "MSSQLSERVER",
  port: "1433"
```

## Example Project

An example project using mssql_ecto with Docker has kindly been created by
[Chase Pursłey](https://github.com/cpursley). It can be viewed
[here](https://github.com/cpursley/mssql_ecto_friends).

## Type Mappings

|    Ecto Type    |   SQL Server Type    |                                                                       Caveats                                                                        |
| :-------------: | :------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------: |
|       :id       |         int          |                                                                                                                                                      |
|     :serial     |  int identity(1, 1)  |                                                                                                                                                      |
|   :bigserial    | bigint identity(1,1) | When a query is returning this value with the `returning` syntax and no schema is used, it will be returned as a string rather than an integer value |
|   :binary_id    |       char(36)       |                                                                                                                                                      |
|      :uuid      |       char(36)       |                                                                                                                                                      |
|     :string     |       nvarchar       |                                                                                                                                                      |
|     :binary     |    nvarchar(4000)    |                                                         Limited size, not fully implemented                                                          |
|    :integer     |         int          |                                                                                                                                                      |
|    :boolean     |         bit          |                                                                                                                                                      |
| {:array, type}  |     list of type     |                                                                    Not Supported                                                                     |
|      :map       |    nvarchar(4000)    |                                                                    Not Supported                                                                     |
|   {:map, \_}    |    nvarchar(4000)    |                                                                    Not Supported                                                                     |
|      :date      |         date         |                                                                                                                                                      |
|      :time      |         time         |                                                               Can write but can't read                                                               |
|  :utc_datetime  |      datetime2       |                                                                                                                                                      |
| :naive_datetime |      datetime2       |                                                                                                                                                      |
|     :float      |        float         |                                                                                                                                                      |
|    :decimal     |       decimal        |                                                                                                                                                      |

## Features not yet implemented

- Table comments
- Column comments
- On conflict
- Upserts

## Contributing

### Test Setup

Running the tests requires an instance of SQL Server running on
`localhost` and certain configuration variables set as environment variables:

- MSSQL_DVR should be set to the ODBC driver to be used. Usually
  `SQL Server Native Client 11.0` on Windows, `ODBC Driver 17 for SQL Server` on
  Linux.
- MSSQL_UID should be set to the name of a login with sufficient permissions,
  e.g. `sa`
- MSSQL_PWD should be set to the password for the above account

The tests will create a database named `mssql_ecto_integration_test`

The script `/bash_scripts/setup_test_db.sh` starts a docker image that holds
the test database.

### Code of Conduct

This project had a
[Code of Conduct](https://github.com/findmypast-oss/mssql_ecto/blob/master/docs/CODE_OF_CONDUCT.md)
if you wish to contribute to this project, please abide by its rules.

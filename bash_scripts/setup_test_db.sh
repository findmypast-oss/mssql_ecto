export MSSQL_UID=sa
export MSSQL_PWD='ThePa$$word'
docker stop test_mssql_server
docker rm test_mssql_server
docker run --name test_mssql_server -e 'ACCEPT_EULA=Y' -e SA_PASSWORD=$MSSQL_PWD -p 1433:1433 -d microsoft/mssql-server-linux
echo 'Created docker container test_mssql_server'

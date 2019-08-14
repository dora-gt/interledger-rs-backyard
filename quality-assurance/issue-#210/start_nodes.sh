#!/bin/bash

if [ -n $INTERLEDGER_RS_DIR ]; then
  cd $INTERLEDGER_RS_DIR
fi

printf "Stopping Interledger nodes\n"

if lsof -Pi :6379 -sTCP:LISTEN -t >/dev/null ; then
    redis-cli -p 6379 shutdown
fi

if lsof -Pi :6380 -sTCP:LISTEN -t >/dev/null ; then
    redis-cli -p 6380 shutdown
fi

if lsof -Pi :6381 -sTCP:LISTEN -t >/dev/null ; then
    redis-cli -p 6381 shutdown
fi

if [ -f dump.rdb ] ; then
    rm -f dump.rdb
fi

if lsof -tPi :8545 ; then
    kill `lsof -tPi :8545`
fi

if lsof -tPi :7770 ; then
    kill `lsof -tPi :7770`
fi

if lsof -tPi :8770 ; then
    kill `lsof -tPi :8770`
fi

if lsof -tPi :9770 ; then
    kill `lsof -tPi :9770`
fi

if lsof -tPi :3000 ; then
    kill `lsof -tPi :3000`
fi

if lsof -tPi :3001 ; then
    kill `lsof -tPi :3001`
fi

if lsof -tPi :3002 ; then
    kill `lsof -tPi :3002`
fi

if lsof -tPi :3003 ; then
    kill `lsof -tPi :3003`
fi
printf "Building interledger.rs... (This may take a couple of minutes)\n"
cargo build --bins
redis-server --version > /dev/null || printf "\e[31mUh oh! You need to install redis-server before running this example\e[m\n"
# Create the logs directory if it doesn't already exist
mkdir -p logs

# Start Redis
redis-server --port 6379 &> logs/redis-alice.log &
redis-server --port 6380 &> logs/redis-bob.log &
redis-server --port 6381 &> logs/redis-charlie.log &
ganache-cli -m "abstract vacuum mammal awkward pudding scene penalty purchase dinner depart evoke puzzle" -i 1 &> logs/ganache.log &
sleep 3
# Turn on debug logging for all of the interledger.rs components
export RUST_LOG=interledger=trace

# Start Alice's settlement engine (ETH)
cargo run --package interledger-settlement-engines -- ethereum-ledger \
--key 380eb0f3d505f087e438eca80bc4df9a7faa24f868e69fc0440261a0fc0567dc \
--server_secret aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
--confirmations 0 \
--poll_frequency 1000 \
--ethereum_endpoint http://127.0.0.1:8545 \
--connector_url http://127.0.0.1:7771 \
--redis_uri redis://127.0.0.1:6379/0 \
--asset_scale 6 \
--watch_incoming true \
--port 3000 \
&> logs/node-alice-settlement-engine-eth.log &

# Start Bob's settlement engine (ETH, XRPL)
cargo run --package interledger-settlement-engines -- ethereum-ledger \
--key cc96601bc52293b53c4736a12af9130abf347669b3813f9ec4cafdf6991b087e \
--server_secret bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
--confirmations 0 \
--poll_frequency 1000 \
--ethereum_endpoint http://127.0.0.1:8545 \
--connector_url http://127.0.0.1:8771 \
--redis_uri redis://127.0.0.1:6380/0 \
--asset_scale 6 \
--watch_incoming true \
--port 3001 \
&> logs/node-bob-settlement-engine-eth.log &

DEBUG="xrp-settlement-engine" \
LEDGER_ADDRESS="r3GDnYaYCk2XKzEDNYj59yMqDZ7zGih94K" \
LEDGER_SECRET="ssnYUDNeNQrNij2EVJG6dDw258jA6" \
CONNECTOR_URL="http://localhost:8771" \
REDIS_PORT=6380 \
ENGINE_PORT=3002 \
ilp-settlement-xrp \
&> logs/node-bob-settlement-engine-xrpl.log &

# Start Charlie's settlement engine (XRPL)
DEBUG="xrp-settlement-engine" \
LEDGER_ADDRESS="rGCUgMH4omQV1PUuYFoMAnA7esWFhE7ZEV" \
LEDGER_SECRET="sahVoeg97nuitefnzL9GHjp2Z6kpj" \
CONNECTOR_URL="http://localhost:9771" \
REDIS_PORT=6381 \
ENGINE_PORT=3003 \
ilp-settlement-xrp \
&> logs/node-charlie-settlement-engine-xrpl.log &
# Start Alice's node
ILP_ADDRESS=example.alice \
ILP_SECRET_SEED=8852500887504328225458511465394229327394647958135038836332350604 \
ILP_ADMIN_AUTH_TOKEN=hi_alice \
ILP_REDIS_CONNECTION=redis://127.0.0.1:6379/0 \
ILP_HTTP_ADDRESS=127.0.0.1:7770 \
ILP_BTP_ADDRESS=127.0.0.1:7768 \
ILP_SETTLEMENT_ADDRESS=127.0.0.1:7771 \
ILP_DEFAULT_SPSP_ACCOUNT=0 \
cargo run --package interledger -- node &> logs/node-alice.log &

# Start Bob's node
ILP_ADDRESS=example.bob \
ILP_SECRET_SEED=1604966725982139900555208458637022875563691455429373719368053354 \
ILP_ADMIN_AUTH_TOKEN=hi_bob \
ILP_REDIS_CONNECTION=redis://127.0.0.1:6380/0 \
ILP_HTTP_ADDRESS=127.0.0.1:8770 \
ILP_BTP_ADDRESS=127.0.0.1:8768 \
ILP_SETTLEMENT_ADDRESS=127.0.0.1:8771 \
ILP_DEFAULT_SPSP_ACCOUNT=0 \
cargo run --package interledger -- node &> logs/node-bob.log &

# Start Charlie's node
ILP_ADDRESS=example.bob.charlie \
ILP_SECRET_SEED=1232362131122139900555208458637022875563691455429373719368053354 \
ILP_ADMIN_AUTH_TOKEN=hi_charlie \
ILP_REDIS_CONNECTION=redis://127.0.0.1:6381/0 \
ILP_HTTP_ADDRESS=127.0.0.1:9770 \
ILP_BTP_ADDRESS=127.0.0.1:9768 \
ILP_SETTLEMENT_ADDRESS=127.0.0.1:9771 \
ILP_DEFAULT_SPSP_ACCOUNT=0 \
cargo run --package interledger -- node &> logs/node-charlie.log &

printf "Waiting for nodes to start up...\n"

function wait_to_serve() {
    while :
    do
        printf "."
        sleep 1
        curl $1 &> /dev/null
        if [ $? -eq 0 ]; then
            break;
        fi
    done
}

wait_to_serve "http://localhost:7770"
wait_to_serve "http://localhost:8770"
wait_to_serve "http://localhost:9770"
wait_to_serve "http://localhost:3000"
wait_to_serve "http://localhost:3001"
wait_to_serve "http://localhost:3002"
wait_to_serve "http://localhost:3003"
printf "\n"

printf "Creating accounts:\n"
# Adding settlement accounts should be done at the same time because it checks each other

printf "Adding Alice's account...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_alice" \
    -d '{
    "ilp_address": "example.alice",
    "asset_code": "ETH",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "http_incoming_token": "in_alice",
    "http_outgoing_token": "out_alice",
    "http_endpoint": "http://localhost:7770/ilp",
    "settle_to" : 0}' \
    http://localhost:7770/accounts > logs/account-alice-alice.log 2>/dev/null

printf "Adding Dave's account...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_alice" \
    -d '{
    "ilp_address": "example.alice.dave",
    "asset_code": "ETH",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "btp_incoming_token": "btp_in_dave",
    "routing_relation": "Child",
    "settle_to" : 0}' \
    http://localhost:7770/accounts > logs/account-alice-dave.log 2>/dev/null

printf "Adding Charlie's Account...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_charlie" \
    -d '{
    "ilp_address": "example.bob.charlie",
    "asset_code": "XRP",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "http_incoming_token": "in_charlie",
    "http_outgoing_token": "out_charlie",
    "http_endpoint": "http://localhost:9770/ilp",
    "settle_to" : 0}' \
    http://localhost:9770/accounts > logs/account-charlie-charlie.log 2>/dev/null

printf "Adding Bob's account on Alice's node (ETH Peer relation)...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_alice" \
    -d '{
    "ilp_address": "example.bob",
    "asset_code": "ETH",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "settlement_engine_url": "http://localhost:3000",
    "http_incoming_token": "bob",
    "http_outgoing_token": "alice",
    "http_endpoint": "http://localhost:8770/ilp",
    "settle_threshold": 300,
    "min_balance": -1000,
    "settle_to" : 0,
    "routing_relation": "Peer",
    "send_routes": true,
    "receive_routes": true}' \
    http://localhost:7770/accounts > logs/account-alice-bob.log 2>/dev/null &

printf "Adding Alice's account on Bob's node (ETH Peer relation)...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_bob" \
    -d '{
    "ilp_address": "example.alice",
    "asset_code": "ETH",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "settlement_engine_url": "http://localhost:3001",
    "http_incoming_token": "alice",
    "http_outgoing_token": "bob",
    "http_endpoint": "http://localhost:7770/ilp",
    "settle_threshold": 300,
    "min_balance": -1000,
    "settle_to" : 0,
    "routing_relation": "Peer",
    "send_routes": true,
    "receive_routes": true}' \
    http://localhost:8770/accounts > logs/account-bob-alice.log 2>/dev/null

printf "Adding Charlie's account on Bob's node (XRP Child relation)...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_bob" \
    -d '{
    "ilp_address": "example.bob.charlie",
    "asset_code": "XRP",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "settlement_engine_url": "http://localhost:3002",
    "http_incoming_token": "charlie",
    "http_outgoing_token": "bob",
    "http_endpoint": "http://localhost:9770/ilp",
    "settle_threshold": 300,
    "min_balance": -1000,
    "settle_to" : 0,
    "routing_relation": "Child",
    "send_routes": false,
    "receive_routes": true}' \
    http://localhost:8770/accounts > logs/account-bob-charlie.log 2>/dev/null &

printf "Adding Bob's account on Charlie's node (XRP Parent relation)...\n"
curl \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_charlie" \
    -d '{
    "ilp_address": "example.bob",
    "asset_code": "XRP",
    "asset_scale": 6,
    "max_packet_amount": 10,
    "settlement_engine_url": "http://localhost:3003",
    "http_incoming_token": "bob",
    "http_outgoing_token": "charlie",
    "http_endpoint": "http://localhost:8770/ilp",
    "settle_threshold": 300,
    "min_balance": -1000,
    "settle_to" : 0,
    "routing_relation": "Parent",
    "send_routes": false,
    "receive_routes": true}' \
    http://localhost:9770/accounts > logs/account-charlie-bob.log 2>/dev/null

sleep 2
printf "\nSetting the exchange rate...\n"
curl http://localhost:8770/rates -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer hi_bob" \
    -d "{ \"ETH\" : 1, \"XRP\": 1 }" \
    &>/dev/null

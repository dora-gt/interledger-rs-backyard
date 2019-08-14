#!/bin/bash

redis-server --port 6379 &> logs/redis-alice.log &
redis-server --port 6380 &> logs/redis-bob.log &
redis-server --port 6381 &> logs/redis-charlie.log &

sleep 3

redis-cli -p 6379 flushall
redis-cli -p 6380 flushall
redis-cli -p 6381 flushall


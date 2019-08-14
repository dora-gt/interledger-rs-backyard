#!/bin/bash

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

if lsof -tPi :10000 ; then
    kill `lsof -tPi :10000`
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


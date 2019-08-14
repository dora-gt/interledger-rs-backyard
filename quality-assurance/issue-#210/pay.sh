#!/bin/bash

curl \
    -H "Authorization: Bearer in_alice" \
    -H "Content-Type: application/json" \
    -d '{"receiver":"http://localhost:9770","source_amount":500}' \
    http://localhost:7770/pay


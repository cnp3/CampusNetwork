#!/bin/bash

echo "Contacting DC1 3 times on prefix 200"
curl "http://[fd00:200:3:100::80]"
curl "http://[fd00:200:3:100::80]"
curl "http://[fd00:200:3:100::80]"

echo "Contacting DC1 3 times on prefix 300"
curl "http://[fd00:300:3:100::80]"
curl "http://[fd00:300:3:100::80]"
curl "http://[fd00:300:3:100::80]"

echo "Contacting DC2 3 times on prefix 200"
curl "http://[fd00:200:3:101::80]"
curl "http://[fd00:200:3:101::80]"
curl "http://[fd00:200:3:101::80]"

echo "Contacting DC2 3 times on prefix 200"
curl "http://[fd00:300:3:101::80]"
curl "http://[fd00:300:3:101::80]"
curl "http://[fd00:300:3:101::80]"

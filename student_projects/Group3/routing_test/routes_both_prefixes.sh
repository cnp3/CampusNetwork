#!/bin/bash

echo "[TEST] Check if intra-domain routing protocol distribute routes for both prefixes"

sudo ip netns exec STEV ip -6 route
exit

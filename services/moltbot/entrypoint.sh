#!/bin/bash
set -e

echo "Starting Moltbot..."

# TODO: Generate config.yaml from env vars

exec moltbot start

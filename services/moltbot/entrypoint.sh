#!/bin/bash
set -e

CONFIG_TEMPLATE="/services/moltbot/config.yaml.template" # I need to make sure this file is COPY'd or mounted
TARGET_CONFIG="/root/.clawdbot/config.yaml"

# Ensure config directory exists
mkdir -p /root/.clawdbot

echo "Waiting for Mattermost Bot Token..."
MAX_RETRIES=30
COUNT=0

while [ ! -f "/bootstrap/bot_token" ]; do
    sleep 2
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "Timeout waiting for bot token from Mattermost."
        # If the user provided it manually in ENV, we might proceed, but for now lets fail or fallback
        if [ -n "$MATTERMOST_BOT_TOKEN" ] && [ "$MATTERMOST_BOT_TOKEN" != "CHANGE_ME_AFTER_SETUP" ]; then
             echo "Using manually provided token from ENV."
             break
        fi
        # exit 1 # Don't exit, just keep waiting or let it fail later
    fi
    echo "Waiting... ($COUNT/$MAX_RETRIES)"
done

if [ -f "/bootstrap/bot_token" ]; then
    echo "Found bot token file."
    export MATTERMOST_BOT_TOKEN=$(cat /bootstrap/bot_token)
fi

echo "Generating config.yaml..."
# We assume the template is at /config.yaml.template. I need to COPY it in Dockerfile.
envsubst < /config.yaml.template > "$TARGET_CONFIG"

echo "Config generated. Starting Moltbot..."
exec moltbot start
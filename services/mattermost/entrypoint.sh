#!/bin/bash
set -e

# Wait for Postgres (simple check, in production use a real wait-for script)
echo "Waiting for Postgres..."
sleep 5

# Start Mattermost in background
/entrypoint.sh mattermost &
MM_PID=$!

# Wait for Mattermost to be ready
echo "Waiting for Mattermost to start..."
until curl -s http://localhost:8065/api/v4/system/ping > /dev/null; do
  sleep 2
done

echo "Mattermost is up! Running provisioning..."

# TODO: Add mmctl logic here to create users/teams

# Keep container running
wait $MM_PID

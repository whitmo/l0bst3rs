#!/bin/bash
set -e

# Start Mattermost in the background
echo "Starting Mattermost Server..."
/entrypoint.sh mattermost &
MM_PID=$!

# Function to check if Mattermost is ready
wait_for_mattermost() {
    echo "Waiting for Mattermost API to be ready..."
    until curl -s -f http://localhost:8065/api/v4/system/ping > /dev/null; do
        sleep 2
    done
    echo "Mattermost is up."
}

wait_for_mattermost

# Check if we need to run the initial setup
if [ ! -f "/bootstrap/setup_complete" ]; then
    echo "Running initial bootstrap..."

    # 1. Create System Admin
    echo "Creating System Admin User..."
    # We use '|| true' because if the user exists from a previous run (but volume persisted), this might fail.
    # However, if volume persisted, /bootstrap/setup_complete should usually exist unless we destroyed the volume.
    mattermost user create --email "${MM_ADMIN_EMAIL}" --username "${MM_ADMIN_USERNAME}" --password "${MM_ADMIN_PASSWORD}" --system_admin || echo "Admin user creation skipped (may already exist)"

    # 2. Authenticate mmctl
    echo "Authenticating mmctl..."
    mmctl auth login http://localhost:8065 --name local --username "${MM_ADMIN_USERNAME}" --password "${MM_ADMIN_PASSWORD}"

    # 3. Create Team
    echo "Creating Team '${MM_TEAM_NAME}'..."
    mmctl team create --name "${MM_TEAM_NAME}" --display-name "${MM_TEAM_DISPLAY_NAME}" || echo "Team creation skipped"

    # 4. Create Bot Account
    echo "Creating Bot 'moltbot'..."
    # Check if bot exists first to avoid error spam
    if ! mmctl bot list --local | grep -q "moltbot"; then
        # Create bot and capture the output which contains the token
        # Output format: "Created bot ... Token: <TOKEN>"
        BOT_OUTPUT=$(mmctl bot create --username moltbot --display-name "Moltbot" --with-token)
        echo "$BOT_OUTPUT"
        
        # Extract token using grep/sed/awk
        # Example output: "Created bot moltbot (id: ...). Token: 7a8b9c..."
        BOT_TOKEN=$(echo "$BOT_OUTPUT" | grep -o 'Token: [a-zA-Z0-9]*' | cut -d ' ' -f 2)
        
        if [ -n "$BOT_TOKEN" ]; then
            echo "Bot token generated: $BOT_TOKEN"
            echo "$BOT_TOKEN" > /bootstrap/bot_token
            chmod 600 /bootstrap/bot_token
        else
            echo "ERROR: Failed to extract bot token."
        fi
        
        # Add bot to the team
        mmctl team users add "${MM_TEAM_NAME}" moltbot@localhost || echo "Could not add bot to team (might verify username format)"
        # Usually bots are added by email or username. 'moltbot' is the username.
        mmctl team users add "${MM_TEAM_NAME}" moltbot
    else
        echo "Bot 'moltbot' already exists."
    fi

    # Mark setup as complete
    touch /bootstrap/setup_complete
    echo "Bootstrap complete."
else
    echo "Bootstrap already completed."
fi

# Keep the container running by waiting for the Mattermost process
wait $MM_PID
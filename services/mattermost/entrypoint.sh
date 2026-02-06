#!/bin/bash
set -e

BOOTSTRAP_MARKER="/bootstrap/setup_complete"

# -------------------------------------------------------
# Step 1: Wait for Postgres readiness
# -------------------------------------------------------
wait_for_postgres() {
    echo "[bootstrap] Waiting for Postgres to accept connections..."
    local retries=0
    until pg_isready -h postgres -p 5432 -U "${POSTGRES_USER:-mmuser}" -q; do
        retries=$((retries + 1))
        if [ "$retries" -ge 30 ]; then
            echo "[bootstrap] ERROR: Postgres not ready after 60s, starting anyway..."
            return 1
        fi
        sleep 2
    done
    echo "[bootstrap] Postgres is ready."
}

# -------------------------------------------------------
# Step 2: Start Mattermost server in the background
# -------------------------------------------------------
start_mattermost() {
    echo "[bootstrap] Starting Mattermost server..."
    /mattermost/bin/mattermost &
    MM_PID=$!
}

# -------------------------------------------------------
# Step 3: Wait for Mattermost API to respond
# -------------------------------------------------------
wait_for_mattermost() {
    echo "[bootstrap] Waiting for Mattermost API..."
    local retries=0
    until curl -sf http://localhost:8065/api/v4/system/ping > /dev/null 2>&1; do
        retries=$((retries + 1))
        if [ "$retries" -ge 60 ]; then
            echo "[bootstrap] ERROR: Mattermost API not ready after 120s"
            return 1
        fi
        sleep 2
    done
    echo "[bootstrap] Mattermost API is up."
}

# -------------------------------------------------------
# Step 4: Provision admin, team, bot via mmctl
# -------------------------------------------------------
provision() {
    echo "[bootstrap] Running provisioning..."

    # 4a. Create system admin user
    echo "[bootstrap] Creating admin user '${MM_ADMIN_USERNAME}'..."
    mmctl user create \
        --email "${MM_ADMIN_EMAIL}" \
        --username "${MM_ADMIN_USERNAME}" \
        --password "${MM_ADMIN_PASSWORD}" \
        --system-admin \
        --local 2>/dev/null \
    || echo "[bootstrap] Admin user may already exist, continuing."

    # 4b. Authenticate mmctl for remote commands
    echo "[bootstrap] Authenticating mmctl..."
    mmctl auth login http://localhost:8065 \
        --name local-server \
        --username "${MM_ADMIN_USERNAME}" \
        --password "${MM_ADMIN_PASSWORD}"

    # 4c. Create team
    echo "[bootstrap] Creating team '${MM_TEAM_NAME}'..."
    mmctl team create \
        --name "${MM_TEAM_NAME}" \
        --display-name "${MM_TEAM_DISPLAY_NAME}" 2>/dev/null \
    || echo "[bootstrap] Team may already exist, continuing."

    # 4d. Add admin to team
    mmctl team users add "${MM_TEAM_NAME}" "${MM_ADMIN_USERNAME}" 2>/dev/null \
    || echo "[bootstrap] Admin may already be on team."

    # 4e. Create bot account and extract token
    echo "[bootstrap] Creating bot 'moltbot'..."
    BOT_OUTPUT=$(mmctl bot create moltbot \
        --display-name "Moltbot" \
        --description "Automated assistant" 2>&1) \
    || echo "[bootstrap] Bot may already exist."

    # If bot was just created, generate a token
    if echo "$BOT_OUTPUT" | grep -q "Created bot"; then
        echo "[bootstrap] Bot created. Generating access token..."
        TOKEN_OUTPUT=$(mmctl token generate moltbot "bootstrap-token" 2>&1) || true
        BOT_TOKEN=$(echo "$TOKEN_OUTPUT" | grep -oP '(?<=token: )\S+' || echo "$TOKEN_OUTPUT" | grep -o '[a-z0-9]\{26\}' | head -1)

        if [ -n "$BOT_TOKEN" ]; then
            echo "[bootstrap] Bot token generated successfully."
            echo "$BOT_TOKEN" > /bootstrap/bot_token
            chmod 600 /bootstrap/bot_token
        else
            echo "[bootstrap] WARNING: Could not extract bot token from output:"
            echo "$TOKEN_OUTPUT"
        fi
    else
        echo "[bootstrap] Bot 'moltbot' already exists."
        # If token file doesn't exist but bot does, generate a new token
        if [ ! -f /bootstrap/bot_token ]; then
            echo "[bootstrap] No token file found, generating new token..."
            TOKEN_OUTPUT=$(mmctl token generate moltbot "bootstrap-token" 2>&1) || true
            BOT_TOKEN=$(echo "$TOKEN_OUTPUT" | grep -oP '(?<=token: )\S+' || echo "$TOKEN_OUTPUT" | grep -o '[a-z0-9]\{26\}' | head -1)
            if [ -n "$BOT_TOKEN" ]; then
                echo "$BOT_TOKEN" > /bootstrap/bot_token
                chmod 600 /bootstrap/bot_token
            fi
        fi
    fi

    # 4f. Add bot to team
    mmctl team users add "${MM_TEAM_NAME}" moltbot 2>/dev/null \
    || echo "[bootstrap] Bot may already be on team."

    # -------------------------------------------------------
    # Step 5: Generate and print invite link
    # -------------------------------------------------------
    echo "[bootstrap] Generating team invite link..."
    INVITE_OUTPUT=$(mmctl team invite-link "${MM_TEAM_NAME}" 2>&1) || true
    if [ -n "$INVITE_OUTPUT" ]; then
        echo ""
        echo "============================================="
        echo "  TEAM INVITE LINK"
        echo "  $INVITE_OUTPUT"
        echo "============================================="
        echo ""
    else
        echo "[bootstrap] Could not generate invite link. Create one manually via mmctl or the UI."
    fi

    # Mark bootstrap as done
    touch "$BOOTSTRAP_MARKER"
    echo "[bootstrap] Provisioning complete."
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
wait_for_postgres
start_mattermost
wait_for_mattermost

if [ ! -f "$BOOTSTRAP_MARKER" ]; then
    provision
else
    echo "[bootstrap] Already provisioned (marker exists). Skipping."
fi

echo "[bootstrap] Mattermost is running (PID $MM_PID)."
wait $MM_PID

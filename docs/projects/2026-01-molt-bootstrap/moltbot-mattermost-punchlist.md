# Moltbot + Mattermost on Mac Mini: Punchlist

## Prerequisites

- [ ] Mac Mini with Apple Silicon
- [ ] macOS 26 (Tahoe) or later
- [ ] Anthropic API key (or Claude Pro/Max subscription)
- [ ] ngrok account (free works, paid for static URL)
- [ ] Domain (optional, for Cloudflare Tunnel alternative)

---

## Phase 1: Apple Container Setup

### Install Apple Container

```bash
# Download from Apple's GitHub releases
# https://github.com/apple/container/releases

# Or build from source (requires Xcode)
git clone https://github.com/apple/container.git
cd container
swift build -c release
```

### Verify Installation

```bash
container --version
container run alpine uname -a
```

---

## Phase 2: Mattermost Container

### Create Mattermost Data Directory

```bash
mkdir -p ~/moltbot-stack/mattermost/{config,data,logs,plugins,bleve-indexes}
mkdir -p ~/moltbot-stack/postgres/data
```

### PostgreSQL Container

```bash
# Start postgres container
container run -d \
  --name mattermost-db \
  -e POSTGRES_USER=mmuser \
  -e POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD \
  -e POSTGRES_DB=mattermost \
  -v ~/moltbot-stack/postgres/data:/var/lib/postgresql/data \
  postgres:15-alpine

# Note the container IP for Mattermost config
container inspect mattermost-db | grep IPAddress
```

### Mattermost Container

```bash
# Pull and run Mattermost
container run -d \
  --name mattermost \
  -p 8065:8065 \
  -e MM_SQLSETTINGS_DRIVERNAME=postgres \
  -e MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:CHANGE_ME_STRONG_PASSWORD@<POSTGRES_IP>:5432/mattermost?sslmode=disable" \
  -e MM_SERVICESETTINGS_SITEURL="https://YOUR_NGROK_URL" \
  -v ~/moltbot-stack/mattermost/config:/mattermost/config \
  -v ~/moltbot-stack/mattermost/data:/mattermost/data \
  -v ~/moltbot-stack/mattermost/logs:/mattermost/logs \
  -v ~/moltbot-stack/mattermost/plugins:/mattermost/plugins \
  -v ~/moltbot-stack/mattermost/bleve-indexes:/mattermost/bleve-indexes \
  mattermost/mattermost-team-edition:latest
```

### Initial Mattermost Setup

- [ ] Open http://localhost:8065
- [ ] Create admin account
- [ ] Create initial team

---

## Phase 3: Moltbot Container

### Moltbot Data Directory

```bash
mkdir -p ~/moltbot-stack/moltbot/{workspace,config}
```

### Moltbot Container

```bash
# Base image with Node.js 22
container run -it \
  --name moltbot \
  -v ~/moltbot-stack/moltbot/workspace:/workspace \
  -v ~/moltbot-stack/moltbot/config:/root/.clawdbot \
  node:22-bookworm bash

# Inside container:
npm install -g moltbot@latest
moltbot onboard
```

### Moltbot Onboarding Choices

During `moltbot onboard`:
- [ ] Select API key auth (or setup-token if using Claude Pro/Max)
- [ ] Skip WhatsApp/Telegram (we're using Mattermost)
- [ ] Enable Mattermost plugin when prompted

### Install Mattermost Plugin

```bash
# Inside moltbot container
moltbot plugins install @openclaw/mattermost
```

### Configure Mattermost Channel

Edit `~/.clawdbot/config.yaml` (or via wizard):

```yaml
channels:
  mattermost:
    enabled: true
    url: "http://<MATTERMOST_CONTAINER_IP>:8065"
    # Create a bot account in Mattermost and get token
    token: "YOUR_MATTERMOST_BOT_TOKEN"
    # Bot username
    username: "moltbot"
    dm:
      policy: "allowlist"  # or "open" for all users
      allowFrom:
        - "approved_user1"
        - "approved_user2"
    groupPolicy: "allowlist"
    groups:
      - "allowed-channel-name"
```

### Create Mattermost Bot Account

In Mattermost:
- [ ] System Console → Integrations → Bot Accounts → Enable
- [ ] Integrations → Bot Accounts → Add Bot
- [ ] Username: `moltbot`
- [ ] Role: Member (or Admin if needed)
- [ ] Copy the access token

---

## Phase 4: ngrok Setup

### Install ngrok

```bash
brew install ngrok
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### Static URL (Paid) or Dynamic (Free)

```bash
# Free (URL changes each restart)
ngrok http 8065

# Paid ($8/mo) - static subdomain
ngrok http --domain=yourname.ngrok-free.app 8065
```

### ngrok Config File (Optional)

Create `~/.ngrok2/ngrok.yml`:

```yaml
version: "2"
authtoken: YOUR_AUTH_TOKEN
tunnels:
  mattermost:
    addr: 8065
    proto: http
    domain: yourname.ngrok-free.app  # paid only
```

Run with: `ngrok start mattermost`

### Update Mattermost Site URL

After getting ngrok URL:
- [ ] System Console → Environment → Web Server
- [ ] Site URL: `https://yourname.ngrok-free.app`
- [ ] Save and restart Mattermost

---

## Phase 5: Invite-Only Authentication

### Disable Open Signup

System Console → Authentication → Signup:
- [ ] Enable Open Server: **false**
- [ ] Restrict signup by email domain (optional): `yourdomain.com`

### Enable Google OAuth (Optional)

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Create OAuth 2.0 Client ID (Web application)
3. Authorized redirect URI: `https://YOUR_NGROK_URL/signup/google/complete`

System Console → Authentication → OAuth 2.0:
- [ ] Enable Google OAuth: **true**
- [ ] Client ID: `your-client-id`
- [ ] Client Secret: `your-client-secret`

### Invite Flow

System Console → Authentication → Signup:
- [ ] Enable Email Invitations: **true**

To invite users:
- Team menu → Invite People → Copy invite link
- Or: System Console → Users → Send invite

---

## Phase 6: Security Hardening

### Mattermost Hardening

System Console → Environment → Web Server:
- [ ] Forward port 80 to 443: **true** (ngrok handles this)

System Console → Site Configuration → Security:
- [ ] Maximum Login Attempts: `5`
- [ ] Enable rate limiting: **true**

System Console → Authentication → Password:
- [ ] Minimum length: `10`
- [ ] Require lowercase, uppercase, number, symbol

System Console → Authentication → Sessions:
- [ ] Session length (days): `7` (or less)
- [ ] Session idle timeout: `30` minutes

### Moltbot Hardening

In `~/.clawdbot/config.yaml`:

```yaml
# Restrict who can talk to the bot
channels:
  mattermost:
    dm:
      policy: "allowlist"
      allowFrom:
        - "user1"
        - "user2"
    groupPolicy: "allowlist"
    groups:
      - "approved-channel"

# Sandbox agent actions
agents:
  defaults:
    sandbox:
      mode: "strict"  # or "non-main"
    
    # Disable dangerous tools for shared instance
    tools:
      disabled:
        - "shell"        # No arbitrary shell commands
        - "filesystem"   # No direct filesystem access (unless needed)
        
    # Or use allowlist instead
    tools:
      enabled:
        - "web_search"
        - "web_fetch"
        - "message"
        - "cron"
        # Add specific tools you want

# Rate limiting per user
rateLimit:
  enabled: true
  messagesPerMinute: 10
  messagesPerHour: 100
```

### Run Security Audit

```bash
moltbot security audit
moltbot security audit --fix  # Auto-fix some issues
```

### Network Isolation

The container already provides isolation, but additionally:
- [ ] Don't mount sensitive host directories
- [ ] Use separate Anthropic API key (not your personal one) with usage limits
- [ ] Consider Anthropic's usage-based billing alerts

---

## Phase 7: Startup Scripts

### Create Launch Script

Create `~/moltbot-stack/start.sh`:

```bash
#!/bin/bash
set -e

echo "Starting PostgreSQL..."
container start mattermost-db
sleep 5

echo "Starting Mattermost..."
container start mattermost
sleep 10

echo "Starting Moltbot..."
container start moltbot

echo "Starting ngrok..."
ngrok start mattermost &

echo "All services started!"
echo "Mattermost: http://localhost:8065"
echo "ngrok URL: check ngrok dashboard"
```

### Create Stop Script

Create `~/moltbot-stack/stop.sh`:

```bash
#!/bin/bash

echo "Stopping services..."
pkill ngrok || true
container stop moltbot
container stop mattermost
container stop mattermost-db
echo "All services stopped."
```

### LaunchAgent for Auto-Start (Optional)

Create `~/Library/LaunchAgents/com.moltbot.stack.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.moltbot.stack</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOU/moltbot-stack/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

Load with: `launchctl load ~/Library/LaunchAgents/com.moltbot.stack.plist`

---

## Phase 8: Making Moltbot Useful (Multi-User Ideas)

### Shared Knowledge Base

Give Moltbot access to shared documents:

```yaml
# In workspace, create a shared knowledge folder
workspace:
  path: "/workspace"
  
skills:
  workspace:
    - name: "shared-docs"
      path: "/workspace/shared-docs"
      description: "Shared team documents and knowledge base"
```

Mount a shared folder: `-v ~/moltbot-stack/shared-docs:/workspace/shared-docs`

Users can ask: "What's in our onboarding doc?" or "Summarize the Q4 plan"

### Per-User Workspaces (Isolated)

Use multi-agent routing for user isolation:

```yaml
agents:
  default:
    # Shared agent for general queries
    
  user_alice:
    workspace: "/workspace/users/alice"
    tools:
      enabled: ["web_search", "web_fetch", "message"]
      
  user_bob:
    workspace: "/workspace/users/bob"
    tools:
      enabled: ["web_search", "web_fetch", "message"]

routing:
  mattermost:
    byUser:
      alice: "user_alice"
      bob: "user_bob"
    default: "default"
```

### Useful Skill Configurations

```yaml
skills:
  bundled:
    # Research assistant
    - web_search
    - web_fetch
    
    # Scheduling (if you set up calendar integration)
    - google_calendar
    
    # Note-taking
    - notes
    
  # Install community skills
  managed:
    - "@clawdhub/summarizer"
    - "@clawdhub/code-review"
```

### Channel-Specific Behaviors

```yaml
channels:
  mattermost:
    groups:
      - name: "research"
        agent: "research_agent"
        systemPrompt: "You are a research assistant. Help users find and summarize information."
        
      - name: "coding"
        agent: "code_agent"
        systemPrompt: "You are a coding assistant. Help with code review, debugging, and explanations."
        tools:
          enabled: ["web_search", "web_fetch"]
          
      - name: "general"
        agent: "default"
```

### Scheduled Tasks

Moltbot can proactively post to channels:

```yaml
cron:
  - name: "daily-summary"
    schedule: "0 9 * * *"  # 9 AM daily
    channel: "mattermost:general"
    prompt: "Search for AI news from the last 24 hours and post a brief summary of the top 3 stories."
    
  - name: "weekly-reminder"
    schedule: "0 10 * * 1"  # Monday 10 AM
    channel: "mattermost:team"
    prompt: "Remind the team it's Monday and wish them a good week."
```

### Fun/Social Features

- **Trivia bot**: Schedule daily trivia questions
- **Link curator**: Summarize links posted in channels
- **Meeting prep**: "Summarize what was discussed in #project this week"
- **Writing assistant**: Help draft messages, emails, docs

### Guardrails for Shared Use

```yaml
agents:
  defaults:
    # Prevent leaking info between users
    sessionIsolation: true
    
    # Keep context shorter for cost control
    maxContextTokens: 50000
    
    # Add system prompt for shared instance behavior
    systemPrompt: |
      You are a helpful assistant shared by multiple users.
      - Keep responses concise
      - Don't reference other users' conversations
      - If asked about other users, politely decline
      - Be helpful but mindful of costs (avoid unnecessary verbosity)
```

---

## Phase 9: Monitoring & Maintenance

### Check Logs

```bash
# Mattermost logs
container logs mattermost

# Moltbot logs
container exec moltbot tail -f ~/.clawdbot/logs/gateway.log

# ngrok status
open http://localhost:4040
```

### Backup

```bash
# Backup script
tar -czf ~/moltbot-backup-$(date +%Y%m%d).tar.gz \
  ~/moltbot-stack/mattermost \
  ~/moltbot-stack/postgres \
  ~/moltbot-stack/moltbot
```

### Update Moltbot

```bash
container exec moltbot npm update -g moltbot@latest
container restart moltbot
```

---

## Quick Reference

| Service | Local URL | Purpose |
|---------|-----------|---------|
| Mattermost | http://localhost:8065 | Chat UI |
| ngrok Inspector | http://localhost:4040 | Tunnel status |
| Moltbot Gateway | ws://localhost:18789 | Bot control plane |

| File | Purpose |
|------|---------|
| `~/moltbot-stack/start.sh` | Start all services |
| `~/moltbot-stack/stop.sh` | Stop all services |
| `~/.clawdbot/config.yaml` | Moltbot config |
| `~/moltbot-stack/mattermost/config/config.json` | Mattermost config |

---

## Troubleshooting

**Moltbot can't connect to Mattermost:**
- Check container IPs: `container inspect mattermost | grep IPAddress`
- Verify bot token is correct
- Check Mattermost allows bot accounts

**Google OAuth redirect error:**
- Ensure Site URL matches ngrok URL exactly
- Check redirect URI in Google Console matches

**Messages not going through:**
- Check allowlist includes the user
- Verify channel/group is in allowed list
- Check `moltbot doctor` output

**High API costs:**
- Reduce `maxContextTokens`
- Use Claude Sonnet instead of Opus for routine tasks
- Add rate limiting per user

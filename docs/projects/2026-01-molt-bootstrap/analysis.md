# Molt Bootstrap: Project Analysis & Plan

## Current State Assessment

The project is a containerized Moltbot + Mattermost stack targeting zero-touch
provisioning on Mac Mini with Apple Containers. The codebase is compact (17 files)
and well-organized.

### Roadmap Milestone Status

| Milestone | Status | Notes |
|-----------|--------|-------|
| M1: Base Config & Structure | **Done** | Project structure, compose.yml, .env.defaults all in place |
| M2: Service Orchestration | **Mostly Done** | 3 services defined, bridge network, volumes. ngrok sidecar not yet added |
| M3: Mattermost Automation | **Done** | Custom image w/ entrypoint.sh does admin, team, bot creation |
| M4: Moltbot Automation | **Done** | Custom image w/ token handoff, config generation, startup |
| M5: Developer Experience | **Done** | Makefile with up/down/logs/build/clean/shell targets |
| M6: Security & Hardening | **Partial** | Secrets via env vars, non-root Mattermost. More to do |

**Summary:** Core milestones 1-5 are substantially complete. The stack should come
up and self-provision. M6 (security) and the punchlist phases 4-9 remain aspirational.

### What's Built and Working (on paper)

1. **Postgres** — Stock image, env-configured, persistent volume
2. **Mattermost** — Custom image that auto-creates admin, team, and bot account.
   Bot token written to shared volume (`/bootstrap/bot_token`)
3. **Moltbot** — Custom image that waits for token, generates config from template,
   starts the bot
4. **Makefile** — Standard lifecycle commands
5. **Env management** — `.env.defaults` with comments indicating which vars need
   secrets from the environment (passwords, API keys)

---

## Issues & Risks

### P0: Likely Broken

1. **Mattermost entrypoint calls itself recursively.** Line 7 of
   `services/mattermost/entrypoint.sh` calls `/entrypoint.sh mattermost` — but the
   custom script *is* `/entrypoint.sh`. The Dockerfile `COPY entrypoint.sh /entrypoint.sh`
   overwrites the stock entrypoint. This will infinite-loop or fail to start the
   actual Mattermost server. Needs to either:
   - Rename the custom script (e.g., `/custom-entrypoint.sh`) and keep the stock
     entrypoint at `/entrypoint.sh`, or
   - Call the Mattermost binary directly (`/opt/mattermost/bin/mattermost` or
     however the stock image starts it)

2. **`mmctl bot list --local`** — The `--local` flag requires the local socket API
   to be enabled. If not configured, bot existence check will fail silently (grep
   returns non-zero → always tries to create). Not critical but adds noise.

### P1: Needs Attention

3. **No health checks in compose.yml.** Moltbot `depends_on: mattermost` only waits
   for the container to start, not for Mattermost to be ready. The entrypoint.sh
   polling loop compensates, but proper `healthcheck` directives would be more robust
   and enable `depends_on: condition: service_healthy`.

4. **Moltbot entrypoint has stale path reference.** Line 4 references
   `/services/moltbot/config.yaml.template` in a comment, but the Dockerfile copies
   to `/config.yaml.template`. The code on line 36 correctly uses `/config.yaml.template`.
   Minor confusion, not a bug.

5. **No `.env.example` file.** `.env.defaults` exists but doesn't list the secrets
   that must be provided (POSTGRES_PASSWORD, MM_ADMIN_PASSWORD, ANTHROPIC_API_KEY).
   Users need to know what to set. The roadmap called for `.env.example`.

6. **`container-compose` vs `docker compose`.** The Makefile uses `container-compose`
   (Apple Container tooling). This is fine if that's the target runtime, but worth
   verifying that `container-compose` supports all the compose.yml features used
   (build context, named volumes, bridge networking, depends_on).

7. **Model reference is outdated.** `config.yaml.template` specifies
   `claude-3-5-sonnet-20240620`. Current model would be `claude-sonnet-4-5-20250929`
   or similar.

### P2: Nice to Have

8. **No `.gitignore` for `.env`.** The gitignore only covers Emacs files. A local
   `.env` with secrets could accidentally be committed.

9. **Roadmap checkboxes are all unchecked** despite most work being done. Updating
   them would help track true remaining work.

10. **No ngrok sidecar** in compose.yml yet. The punchlist describes manual ngrok
    setup. Adding it as an optional service would complete M2.

---

## Recommended Plan

### Phase 1: Fix the Showstopper (P0)

**Fix Mattermost entrypoint recursion.**

- Determine the stock entrypoint path in the `mattermost/mattermost-team-edition` image
  (likely something like `/entrypoint.sh` calling the mattermost binary)
- Either:
  - Save the stock entrypoint before overwriting, or
  - Call the mattermost binary directly in the custom script, or
  - Rename the custom entrypoint and use it as `CMD` while keeping stock `ENTRYPOINT`

This is the one thing that will prevent the stack from starting.

### Phase 2: Make it Actually Run

1. **Add health checks** to compose.yml for postgres and mattermost so `depends_on`
   works correctly
2. **Create `.env.example`** listing all required variables with placeholder values
3. **Add `.env` to `.gitignore`** to prevent secret leakage
4. **Test the full `make up` → `make logs` cycle** on an actual Apple Container
   runtime (or Docker as fallback)

### Phase 3: Polish

1. **Update roadmap.md** — check off completed milestones, note remaining items
2. **Update model reference** in config.yaml.template
3. **Clean up stale comments** in moltbot entrypoint.sh
4. **Consider adding ngrok** as an optional compose service (gated by env var)

### Phase 4: Security (M6 from Roadmap)

Per the roadmap and punchlist phase 6:
1. Add rate limiting config to moltbot template
2. Switch DM/group policy from "open" to "allowlist" for non-test deployments
3. Add container resource limits in compose.yml
4. Document secret rotation procedure

### Out of Scope (Punchlist Phases 7-9)

The punchlist describes LaunchAgent auto-start, multi-user workspaces,
channel-specific agents, cron jobs, and monitoring. These are future work and should
not be attempted until the core stack is verified working end-to-end.

---

## Key Questions for the Team

1. **Has `make up` been tested?** The entrypoint recursion bug suggests it may not
   have been run yet. A quick smoke test would validate or invalidate the whole stack.

2. **Is Apple Container (`container-compose`) the hard requirement?** Or should this
   also work with standard `docker compose`? Affects testing strategy.

3. **Is `moltbot` a real npm package?** Need to verify `npm install -g moltbot@latest`
   actually resolves. If it's a private package, the Dockerfile needs auth.

4. **What's the deployment target?** Single Mac Mini? Multiple machines? This affects
   whether ngrok/tunneling is phase 1 or phase 3.

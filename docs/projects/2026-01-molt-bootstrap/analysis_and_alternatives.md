# Critical Analysis & Alternatives: Molt Bootstrap

## Executive Summary
The current roadmap relies heavily on imperative shell scripts (`start.sh`, `stop.sh`) and manual networking configuration (`grep IPAddress`). while functional for a "happy path" prototype, this approach is brittle, difficult to maintain, and prone to race conditions. A shift towards declarative definitions and established orchestration patterns is recommended.

## Critical Concerns

### 1. Networking Fragility
- **Current Plan:** Explicitly inspecting container IPs (`container inspect ... | grep IPAddress`) and passing them as environment variables.
- **Risk:** Container IPs are ephemeral. If the database restarts and gets a new IP, Mattermost will fail to connect until manually reconfigured.
- **Impact:** High maintenance burden; "flaky" infrastructure.

### 2. Imperative Scripting ("Shell Script Hell")
- **Current Plan:** `setup.sh`, `start.sh`, `stop.sh` managing state.
- **Risk:** Shell scripts are notoriously hard to make idempotent (safe to run multiple times). Handling edge cases (e.g., "Postgres is running but not ready yet") requires complex "wait-for" logic.
- **Impact:** Poor developer experience; debugging scripts is tedious.

### 3. Manual Configuration & Secrets
- **Current Plan:** "CHANGE_ME" placeholders in commands and interactive `moltbot onboard` steps.
- **Risk:** Secrets ending up in shell history or committed files. Manual steps break the "one-click" promise.
- **Impact:** Security risks and friction in setup.

### 4. Tool Specificity ("Apple Container")
- **Current Plan:** Strict dependency on `github.com/apple/container`.
- **Risk:** Potential lack of ecosystem tools (like `docker-compose` equivalents) that standard runtimes enjoy.
- **Impact:** We may be reinventing orchestration features that exist for free elsewhere.

## Proposed Alternatives

### Alternative A: The "Compose" Standard (Recommended)
If the container runtime supports the OCI standard or has a Compose compatibility layer:
- **Solution:** Use a `docker-compose.yaml` file.
- **Benefits:**
    - **Automatic Networking:** Service discovery by hostname (`db` instead of `172.17.0.2`).
    - **Declarative:** Define *what* you want, not *how* to start it.
    - **Restart Policies:** Handles crashes automatically.
- **Action:** Investigate if `apple/container` supports Compose or if we can use a wrapper (e.g., `podman-compose`).

### Alternative B: Robust Scripting with Task Runners
If we must use shell commands:
- **Solution:** Use a task runner like `Just` (Justfile) or `Make` instead of raw shell scripts. Combine with a strictly defined `.env` file structure.
- **Networking Fix:** Create a dedicated user-defined bridge network so containers can talk by name, removing the need for `grep IPAddress`.
    - *Example:* `container network create molt-net` -> `container run --network molt-net ...`

### Alternative C: Fully Automated Provisioning
To remove manual steps in Mattermost/Moltbot:
- **Mattermost:** Use `mmctl` (Mattermost CLI) in a temporary container to create the admin user, team, and bot account via the API immediately after startup.
- **Moltbot:** Skip `onboard` wizard. Pre-generate `config.yaml` using `envsubst` (templating) to inject API keys and hostnames before starting the container.

## Revised Roadmap Recommendations

1.  **Prioritize Network Discovery:** Stop extracting IPs. Figure out DNS/Hostname resolution between containers immediately.
2.  **Adopt a Task Runner:** Use `Justfile` or `Makefile` to encapsulate commands.
3.  **Automate Internals:** Add a "provisioning" step that uses `mmctl` and configuration templating to eliminate the "Open Browser... Click this..." instructions.

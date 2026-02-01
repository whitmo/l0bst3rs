# Molt Bootstrap Roadmap

**Goal:** Create a replicable, automated local setup for the Moltbot + Mattermost stack using `container-compose` and self-provisioning container images.

## Principles
- **Declarative Infrastructure:** Use `container-compose.yml` to define services, networks, and volumes.
- **Encapsulation:** Complexity belongs inside the container images (custom entrypoints), not in host-side shell scripts.
- **Zero-Touch Provisioning:** The stack should come up fully configured (users, teams, bots) without manual UI interaction.

## Milestones

### Milestone 1: Base Configuration & Structure
- [ ] Define the project structure:
    ```text
    /
    ├── compose.yml
    ├── .env.example
    ├── services/
    │   ├── mattermost/
    │   │   ├── Dockerfile (or Containerfile)
    │   │   └── entrypoint.sh
    │   └── moltbot/
    │       ├── Dockerfile
    │       └── entrypoint.sh
    ```
- [ ] Create `.env.example` for all configurable secrets and ports.

### Milestone 2: Service Orchestration (`container-compose`)
- [ ] Create `compose.yml` to define:
    - `postgres`: Standard database service.
    - `mattermost`: Custom build (see M3).
    - `moltbot`: Custom build (see M4).
    - `ngrok`: Sidecar service (optional).
- [ ] Define a shared bridge network so services can communicate by hostname (`mattermost`, `postgres`).

### Milestone 3: Mattermost Automation (Encapsulated)
- [ ] Create a custom Mattermost image:
    - Install `mmctl`.
    - Write a custom `entrypoint.sh`:
        1. Wait for Postgres readiness.
        2. Initialize Mattermost.
        3. Run `mmctl` commands to create the admin user, team, and bot account.
        4. Generate an invite code/link and print it to logs.

### Milestone 4: Moltbot Automation (Encapsulated)
- [ ] Create a custom Moltbot image:
    - Write a custom `entrypoint.sh`:
        1. Wait for Mattermost service readiness.
        2. Generate `config.yaml` from environment variables (injecting the bot token).
        3. Start Moltbot.

### Milestone 5: Developer Experience
- [ ] Create a minimal `Makefile` or `Justfile` for common tasks:
    - `make up`: Runs `container-compose up`.
    - `make down`: Runs `container-compose down`.
    - `make logs`: Tails logs.

### Milestone 6: Security & Hardening
- [ ] Ensure secrets are passed strictly via environment variables (not baked into images).
- [ ] Review container privileges (run as non-root where possible).

## Future Research
- [ ] Investigate "container-compose" specifics if different from standard Docker Compose.

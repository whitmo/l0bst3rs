# Molt Bootstrap Roadmap

**Goal:** Create a replicable, automated local setup for the Moltbot + Mattermost stack using shell scripts and containerization.

## Principles
- **Simplicity:** Use shell scripts and standard container commands (Apple Container/Docker) initially.
- **Configurability:** Allow users to customize ports, passwords, and tokens via a configuration file.
- **Modularity:** Separate the setup, startup, and teardown processes.

## Milestones

### Milestone 1: Foundation & Directory Structure
- [ ] Define the standard directory structure (`~/moltbot-stack` or similar, configurable).
- [ ] Create a `setup.sh` script to:
    - Verify prerequisites (Apple Container, `git`, etc.).
    - Create necessary subdirectories for data persistence (`mattermost/data`, `postgres/data`, `moltbot/workspace`, etc.).

### Milestone 2: Core Services Orchestration
- [ ] Implement `start.sh` to launch services in order:
    1.  PostgreSQL
    2.  Mattermost (waiting for DB)
    3.  Moltbot
- [ ] Implement `stop.sh` to gracefully shut down services.
- [ ] Ensure containers are named consistently for easy management.
- [ ] Handle container networking (ensure containers can communicate, preferably via a dedicated bridge network rather than relying on manual IP inspection if possible with Apple Container, or automate the IP discovery).

### Milestone 3: Configuration Management
- [ ] Create a `config.env.example` file containing:
    - Postgres credentials
    - Mattermost ports and settings
    - Moltbot tokens
    - ngrok configuration
- [ ] Update scripts to source `config.env` if it exists.
- [ ] Implement basic validation (warn if default passwords are used).

### Milestone 4: Moltbot & Mattermost Integration
- [ ] Automate `config.yaml` generation for Moltbot based on environment variables.
- [ ] Research `mmctl` (Mattermost CLI) to potentially automate:
    - Admin account creation.
    - Bot account creation and token retrieval.
- [ ] Provide clear instructions for any remaining manual steps (e.g., "Paste this token into `config.env`").

### Milestone 5: External Access (ngrok)
- [ ] Integrate `ngrok` startup into `start.sh` (optional, enabled via config).
- [ ] Automate updating Mattermost `SiteURL` if ngrok URL changes (or document the static domain requirement).

### Milestone 6: Security & Hardening (Future)
- [ ] Add flags/options for security hardening (e.g., `start.sh --secure`).
- [ ] Automate generation of strong random passwords for the initial setup.

## Future Research (IaaC)
- [ ] Evaluate `docker-compose` compatibility with Apple Container (if applicable) or alternative orchestration tools for a more declarative approach.
- [ ] Consider Terraform or Ansible if complexity grows beyond shell scripts.

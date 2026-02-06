FROM mattermost/mattermost-team-edition:latest

USER root

# Install utilities for health checks and provisioning
RUN apt-get update && apt-get install -y jq curl postgresql-client && rm -rf /var/lib/apt/lists/*

# Create bootstrap directory (also mounted as a volume for sharing with moltbot)
RUN mkdir -p /bootstrap && chown mattermost:mattermost /bootstrap

COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

USER mattermost
ENTRYPOINT ["/custom-entrypoint.sh"]

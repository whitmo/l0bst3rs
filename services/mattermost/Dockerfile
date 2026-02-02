FROM mattermost/mattermost-team-edition:latest

# Install jq and curl for API interactions
USER root
RUN apt-get update && apt-get install -y jq curl && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER mattermost
ENTRYPOINT ["/entrypoint.sh"]

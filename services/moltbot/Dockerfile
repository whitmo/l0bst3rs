FROM node:22-bookworm

RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*

RUN npm install -g moltbot@latest

COPY entrypoint.sh /entrypoint.sh
COPY config.yaml.template /config.yaml.template
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]

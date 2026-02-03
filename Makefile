# Load defaults if .env doesn't exist or isn't full
include .env.defaults
export $(shell sed 's/=.*//' .env.defaults)

# If a local .env exists, include it (but don't commit it!)
-include .env
export

# Helper to run with 1Password if available, otherwise just run
# Usage: make up
# Or: aix make up

.PHONY: up down logs build clean shell-mm shell-molt help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%%-30s\033[0m %%s\n", $$1, $$2}'

up: ## Start the stack (detached)
	container-compose up -d

build: ## Build images
	container-compose build

down: ## Stop the stack
	container-compose down

logs: ## Tail logs for all services
	container-compose logs -f

clean: ## Stop and remove volumes (WARNING: Destructive)
	container-compose down -v

shell-mm: ## Open a shell in the Mattermost container
	container exec -it $$(container-compose ps -q mattermost) /bin/bash

shell-molt: ## Open a shell in the Moltbot container
	container exec -it $$(container-compose ps -q moltbot) /bin/bash


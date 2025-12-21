# Orion-Sentinel-DataAICore Makefile
# Convenience targets for common operations
#
# Usage:
#   make help          Show available targets
#   make bootstrap     Run bootstrap script
#   make up            Start all core services
#   make down          Stop all services
#   make logs          View logs
#   make doctor        Run health checks

.PHONY: help bootstrap up down ps logs doctor update clean pull-model

# Default target
help:
	@echo "Orion-Sentinel-DataAICore Makefile"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap      Run bootstrap script (first time setup)"
	@echo "  up             Start all core services"
	@echo "  down           Stop all services"
	@echo "  ps             Show running containers"
	@echo "  logs           View logs (all services)"
	@echo "  doctor         Run health checks"
	@echo "  update         Pull latest images"
	@echo "  clean          Stop services and prune Docker"
	@echo "  pull-model     Pull default LLM model (llama3.2:3b)"
	@echo ""
	@echo "Stack-specific:"
	@echo "  up-nextcloud   Start Nextcloud only"
	@echo "  up-websearch   Start SearXNG only"
	@echo "  up-llm         Start LLM stack only"
	@echo ""

# Bootstrap
bootstrap:
	@./scripts/bootstrap-dataaicore.sh

# Start services
up:
	@./scripts/orionctl up core

up-nextcloud:
	@./scripts/orionctl up nextcloud

up-websearch:
	@./scripts/orionctl up websearch

up-llm:
	@./scripts/orionctl up llm

up-public:
	@./scripts/orionctl up nextcloud public-nextcloud

# Stop services
down:
	@./scripts/orionctl down

# Show status
ps:
	@./scripts/orionctl ps

# View logs
logs:
	@./scripts/orionctl logs

# Health check
doctor:
	@./scripts/orionctl doctor

# Update images
update:
	@./scripts/orionctl update

# Clean up
clean:
	@./scripts/orionctl down
	@docker system prune -f

# Pull default model
pull-model:
	@./scripts/pull-model.sh llama3.2:3b

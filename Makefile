# Makefile for Frappe Docker Production Setup
# Provides convenient shortcuts for common operations

.PHONY: help setup validate deploy status logs stop restart update health backup clean

# Default target
help: ## Show this help message
	@echo "Frappe Docker Production Management"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make setup          # Initialize environment"
	@echo "  make deploy         # Deploy production stack"
	@echo "  make site SITE=erp.example.com  # Create new site"
	@echo "  make logs SERVICE=backend       # View backend logs"

setup: ## Initialize environment configuration
	./setup-production.sh setup

validate: ## Validate environment configuration
	./setup-production.sh validate

deploy: ## Deploy the production stack
	./setup-production.sh deploy

status: ## Show service status and resource usage
	./setup-production.sh status

logs: ## Show logs for all services or specific service (use SERVICE=name)
ifdef SERVICE
	./setup-production.sh logs $(SERVICE)
else
	./setup-production.sh logs
endif

stop: ## Stop all services
	./setup-production.sh stop

restart: ## Restart all services
	./setup-production.sh restart

update: ## Update to latest images
	./setup-production.sh update

health: ## Run comprehensive health check
	./health-check.sh

site: ## Create a new site (use SITE=sitename)
ifndef SITE
	@echo "Error: Please specify SITE parameter"
	@echo "Usage: make site SITE=yourdomain.com"
	@exit 1
endif
	./setup-production.sh create-site $(SITE)

backup: ## Create backup for a site (use SITE=sitename)
ifndef SITE
	@echo "Error: Please specify SITE parameter"
	@echo "Usage: make backup SITE=yourdomain.com"
	@exit 1
endif
	./setup-production.sh backup $(SITE)

clean: ## Clean up unused Docker resources
	@echo "Cleaning up unused Docker resources..."
	docker system prune -f
	docker volume prune -f
	@echo "Cleanup completed!"

# Development targets
dev-up: ## Start development environment
	docker compose up -d

dev-down: ## Stop development environment
	docker compose down

dev-logs: ## Show development logs
	docker compose logs -f

# Advanced management
scale-backend: ## Scale backend workers (use REPLICAS=number)
ifndef REPLICAS
	@echo "Error: Please specify REPLICAS parameter"
	@echo "Usage: make scale-backend REPLICAS=3"
	@exit 1
endif
	docker compose -f docker-compose.production.yml up -d --scale backend=$(REPLICAS)

scale-queue: ## Scale queue workers (use REPLICAS=number)
ifndef REPLICAS
	@echo "Error: Please specify REPLICAS parameter"
	@echo "Usage: make scale-queue REPLICAS=2"
	@exit 1
endif
	docker compose -f docker-compose.production.yml up -d --scale queue-short=$(REPLICAS) --scale queue-long=$(REPLICAS)

shell: ## Access backend shell
	docker compose -f docker-compose.production.yml exec backend bash

db-shell: ## Access database shell
	docker compose -f docker-compose.production.yml exec db mysql -u root -p

redis-shell: ## Access Redis shell
	docker compose -f docker-compose.production.yml exec redis-cache redis-cli

# Monitoring
monitor: ## Show real-time resource usage
	watch -n 2 'docker stats --no-stream'

disk-usage: ## Show Docker disk usage
	docker system df -v

# Maintenance
migrate: ## Run database migrations for a site (use SITE=sitename)
ifndef SITE
	@echo "Error: Please specify SITE parameter"
	@echo "Usage: make migrate SITE=yourdomain.com"
	@exit 1
endif
	docker compose -f docker-compose.production.yml exec backend bench --site $(SITE) migrate

bench: ## Run bench command (use CMD="command")
ifndef CMD
	@echo "Error: Please specify CMD parameter"
	@echo "Usage: make bench CMD=\"--site yourdomain.com doctor\""
	@exit 1
endif
	docker compose -f docker-compose.production.yml exec backend bench $(CMD)
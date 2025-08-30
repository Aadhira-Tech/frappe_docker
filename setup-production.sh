#!/bin/bash

# Frappe Docker Production Setup Script
# This script helps you deploy Frappe/ERPNext in production using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker and Docker Compose are installed
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Docker and Docker Compose are installed."
}

# Create environment file from template
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f "production.env" ]; then
            cp production.env .env
            print_success "Created .env file from production.env template."
            print_warning "Please edit .env file with your production settings before continuing."
            print_warning "Key settings to configure:"
            print_warning "  - DOMAIN: Your domain name"
            print_warning "  - SITES: List of sites for SSL certificates"
            print_warning "  - LETSENCRYPT_EMAIL: Email for SSL certificates"
            print_warning "  - DB_PASSWORD: Secure database password"
        else
            print_error "production.env template not found!"
            exit 1
        fi
    else
        print_warning ".env file already exists. Skipping environment setup."
    fi
}

# Validate environment configuration
validate_environment() {
    print_status "Validating environment configuration..."
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found! Run setup first."
        exit 1
    fi
    
    # Extract variables safely
    DOMAIN=$(grep "^DOMAIN=" .env | cut -d'=' -f2)
    SITES=$(grep "^SITES=" .env | cut -d'=' -f2)
    LETSENCRYPT_EMAIL=$(grep "^LETSENCRYPT_EMAIL=" .env | cut -d'=' -f2)
    DB_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d'=' -f2)
    
    # Check required variables
    required_vars=("DOMAIN" "SITES" "LETSENCRYPT_EMAIL" "DB_PASSWORD")
    missing_vars=()
    
    if [ -z "$DOMAIN" ]; then missing_vars+=("DOMAIN"); fi
    if [ -z "$SITES" ]; then missing_vars+=("SITES"); fi
    if [ -z "$LETSENCRYPT_EMAIL" ]; then missing_vars+=("LETSENCRYPT_EMAIL"); fi
    if [ -z "$DB_PASSWORD" ]; then missing_vars+=("DB_PASSWORD"); fi
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}"
        print_error "Please update your .env file."
        exit 1
    fi
    
    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        print_warning "Domain format might be invalid: $DOMAIN"
    fi
    
    # Validate email format
    if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_warning "Email format might be invalid: $LETSENCRYPT_EMAIL"
    fi
    
    print_success "Environment validation completed."
}

# Deploy the stack
deploy() {
    print_status "Deploying Frappe Docker production stack..."
    
    # Pull images
    print_status "Pulling Docker images..."
    docker compose -f docker-compose.production.yml pull
    
    # Start services
    print_status "Starting services..."
    docker compose -f docker-compose.production.yml up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service health
    print_status "Checking service health..."
    docker compose -f docker-compose.production.yml ps
    
    print_success "Deployment completed!"
    print_status "Services are starting up. It may take a few minutes for all services to be fully ready."
}

# Create first site
create_site() {
    if [ -z "$1" ]; then
        print_error "Usage: $0 create-site <site-name>"
        print_error "Example: $0 create-site erp.example.com"
        exit 1
    fi
    
    local site_name=$1
    
    print_status "Creating site: $site_name"
    
    # Check if backend is running
    if ! docker compose -f docker-compose.production.yml ps backend | grep -q "running"; then
        print_error "Backend service is not running. Please deploy first."
        exit 1
    fi
    
    # Create the site
    print_status "Creating new site..."
    docker compose -f docker-compose.production.yml exec backend bench new-site "$site_name" --admin-password admin --mariadb-root-password "${DB_PASSWORD:-frappe123}"
    
    # Set as default site if it's the first one
    if ! docker compose -f docker-compose.production.yml exec backend test -f sites/currentsite.txt; then
        print_status "Setting as default site..."
        docker compose -f docker-compose.production.yml exec backend bash -c "echo '$site_name' > sites/currentsite.txt"
    fi
    
    # Install ERPNext if not already installed
    print_status "Installing ERPNext app..."
    docker compose -f docker-compose.production.yml exec backend bench --site "$site_name" install-app erpnext || true
    
    print_success "Site $site_name created successfully!"
    print_status "Default admin credentials:"
    print_status "  Username: Administrator"
    print_status "  Password: admin"
    print_warning "Please change the admin password after first login!"
}

# Show logs
show_logs() {
    local service=${1:-}
    
    if [ -n "$service" ]; then
        print_status "Showing logs for service: $service"
        docker compose -f docker-compose.production.yml logs -f "$service"
    else
        print_status "Showing logs for all services..."
        docker compose -f docker-compose.production.yml logs -f
    fi
}

# Stop services
stop() {
    print_status "Stopping services..."
    docker compose -f docker-compose.production.yml down
    print_success "Services stopped."
}

# Restart services
restart() {
    print_status "Restarting services..."
    docker compose -f docker-compose.production.yml restart
    print_success "Services restarted."
}

# Show status
status() {
    print_status "Service Status:"
    docker compose -f docker-compose.production.yml ps
    
    print_status "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# Backup
backup() {
    local site_name=${1:-}
    
    if [ -z "$site_name" ]; then
        print_error "Usage: $0 backup <site-name>"
        exit 1
    fi
    
    print_status "Creating backup for site: $site_name"
    docker compose -f docker-compose.production.yml exec backend bench --site "$site_name" backup --with-files
    print_success "Backup completed!"
}

# Update
update() {
    print_status "Updating Frappe Docker stack..."
    
    # Pull new images
    docker compose -f docker-compose.production.yml pull
    
    # Restart services with new images
    docker compose -f docker-compose.production.yml up -d
    
    print_success "Update completed!"
}

# Main script logic
case "${1:-}" in
    "setup")
        check_requirements
        setup_environment
        ;;
    "validate")
        validate_environment
        ;;
    "deploy")
        check_requirements
        validate_environment
        deploy
        ;;
    "create-site")
        create_site "$2"
        ;;
    "logs")
        show_logs "$2"
        ;;
    "stop")
        stop
        ;;
    "restart")
        restart
        ;;
    "status")
        status
        ;;
    "backup")
        backup "$2"
        ;;
    "update")
        update
        ;;
    *)
        echo "Frappe Docker Production Setup Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup              Initialize environment configuration"
        echo "  validate           Validate environment configuration"
        echo "  deploy             Deploy the production stack"
        echo "  create-site <name> Create a new site"
        echo "  logs [service]     Show logs (optionally for specific service)"
        echo "  stop               Stop all services"
        echo "  restart            Restart all services"
        echo "  status             Show service status and resource usage"
        echo "  backup <site>      Create backup for a site"
        echo "  update             Update to latest images"
        echo ""
        echo "Examples:"
        echo "  $0 setup"
        echo "  $0 deploy"
        echo "  $0 create-site erp.example.com"
        echo "  $0 logs backend"
        echo "  $0 backup erp.example.com"
        ;;
esac
#!/bin/bash

# Docker Health Check Script
# This script monitors the health of all production services

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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if docker-compose file exists
if [ ! -f "docker-compose.production.yml" ]; then
    print_error "docker-compose.production.yml not found!"
    exit 1
fi

print_status "Frappe Docker Production Health Check"
echo "========================================"

# Check service status
print_status "Checking service status..."
services=$(docker compose -f docker-compose.production.yml ps --services)
healthy=0
unhealthy=0

for service in $services; do
    status=$(docker compose -f docker-compose.production.yml ps "$service" --format "table {{.Status}}" | tail -n +2)
    
    if echo "$status" | grep -q "running"; then
        if echo "$status" | grep -q "healthy"; then
            print_success "$service: Running and healthy"
            ((healthy++))
        elif echo "$status" | grep -q "unhealthy"; then
            print_error "$service: Running but unhealthy"
            ((unhealthy++))
        else
            print_warning "$service: Running (health check pending)"
            ((healthy++))
        fi
    else
        print_error "$service: Not running"
        ((unhealthy++))
    fi
done

echo
print_status "Health Summary: $healthy healthy, $unhealthy unhealthy"

# Check resource usage
print_status "Checking resource usage..."
echo "Memory Usage by Service:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}" | grep -E "(frontend|backend|db|redis|proxy|queue|scheduler|websocket)"

echo

# Check disk usage
print_status "Checking disk usage..."
echo "Docker Volume Usage:"
docker system df -v | grep -A 10 "Local Volumes"

echo

# Check logs for errors
print_status "Checking recent errors in logs..."
recent_errors=$(docker compose -f docker-compose.production.yml logs --since="1h" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
if [ "$recent_errors" -gt 0 ]; then
    print_warning "Found $recent_errors error messages in the last hour"
    print_status "Recent errors:"
    docker compose -f docker-compose.production.yml logs --since="1h" 2>&1 | grep -i "error\|exception\|failed" | tail -5
else
    print_success "No recent errors found in logs"
fi

echo

# Check SSL certificate status
print_status "Checking SSL certificate status..."
if docker compose -f docker-compose.production.yml ps proxy | grep -q "running"; then
    cert_info=$(docker compose -f docker-compose.production.yml exec proxy ls -la /letsencrypt/acme.json 2>/dev/null || echo "Certificate file not found")
    if echo "$cert_info" | grep -q "acme.json"; then
        print_success "SSL certificate file exists"
        cert_size=$(echo "$cert_info" | awk '{print $5}')
        if [ "$cert_size" -gt 100 ]; then
            print_success "Certificate file has content (${cert_size} bytes)"
        else
            print_warning "Certificate file is too small, might be empty"
        fi
    else
        print_warning "SSL certificate file not found"
    fi
else
    print_error "Proxy service not running, cannot check SSL status"
fi

echo

# Final assessment
if [ $unhealthy -eq 0 ]; then
    print_success "Overall Status: All services are healthy! 🎉"
    exit 0
else
    print_error "Overall Status: $unhealthy services need attention"
    exit 1
fi
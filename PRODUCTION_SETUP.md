# Frappe Docker Production Setup Guide

This guide provides a comprehensive production-ready setup for Frappe/ERPNext using Docker. The setup includes all necessary components for a robust production deployment with automatic SSL, load balancing, and proper security configurations.

## Features

🚀 **Production-Ready Components:**
- MariaDB database with optimized configuration
- Redis for caching and job queues with persistence
- Traefik reverse proxy with automatic HTTPS/SSL
- Comprehensive health checks and monitoring
- Resource limits and logging configuration
- Automatic service restarts

🔒 **Security & SSL:**
- Automatic SSL certificates via Let's Encrypt
- Secure database with custom credentials
- Proper network isolation
- Real IP detection for logs

📊 **Monitoring & Maintenance:**
- Health checks for all services
- Structured logging with rotation
- Resource monitoring
- Backup functionality

## Quick Start

### 1. Prerequisites

Ensure you have the following installed on your server:
- [Docker](https://docs.docker.com/get-docker/) (version 20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (version 2.0+)
- A domain name pointing to your server
- Open ports 80 and 443 on your firewall

### 2. Download and Setup

```bash
# Clone the repository
git clone https://github.com/Aadhira-Tech/frappe_docker.git
cd frappe_docker

# Initialize the production environment
./setup-production.sh setup
```

### 3. Configure Environment

Edit the `.env` file with your production settings:

```bash
nano .env
```

**Required settings to update:**
```bash
# Your domain configuration
DOMAIN=yourdomain.com
SITES=`yourdomain.com`
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Secure database password
DB_PASSWORD=YourSecurePasswordHere123!
```

### 4. Validate and Deploy

```bash
# Validate your configuration
./setup-production.sh validate

# Deploy the production stack
./setup-production.sh deploy
```

### 5. Create Your First Site

```bash
# Create a new site (replace with your domain)
./setup-production.sh create-site yourdomain.com
```

### 6. Access Your Site

Your Frappe/ERPNext installation will be available at:
- **Main Site:** https://yourdomain.com
- **Traefik Dashboard:** https://traefik.yourdomain.com:8080

**Default login credentials:**
- Username: `Administrator`
- Password: `admin`

> ⚠️ **Important:** Change the default password immediately after first login!

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Traffic                         │
│                         ↓                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Traefik Proxy                        │   │
│  │           (SSL Termination)                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ↓                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Frontend (Nginx)                     │   │
│  │            (Static Assets & Routing)               │   │
│  └─────────────────────────────────────────────────────┘   │
│           ↓                              ↓                  │
│  ┌─────────────────┐                ┌──────────────────┐   │
│  │   Backend       │                │   WebSocket      │   │
│  │  (Gunicorn)     │                │   (Socket.IO)    │   │
│  └─────────────────┘                └──────────────────┘   │
│           ↓                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Queue Workers                          │   │
│  │         (Short & Long Queues)                      │   │
│  └─────────────────────────────────────────────────────┘   │
│           ↓                              ↓                  │
│  ┌─────────────────┐                ┌──────────────────┐   │
│  │    MariaDB      │                │      Redis       │   │
│  │   (Database)    │                │ (Cache & Queue)  │   │
│  └─────────────────┘                └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Management Commands

The `setup-production.sh` script provides convenient management commands:

### Service Management
```bash
# View service status
./setup-production.sh status

# View logs (all services)
./setup-production.sh logs

# View logs for specific service
./setup-production.sh logs backend

# Restart services
./setup-production.sh restart

# Stop services
./setup-production.sh stop
```

### Site Management
```bash
# Create a new site
./setup-production.sh create-site newsite.com

# Create backup
./setup-production.sh backup yourdomain.com

# Access backend shell
docker compose -f docker-compose.production.yml exec backend bash
```

### Maintenance
```bash
# Update to latest images
./setup-production.sh update

# Scale services (example: 3 backend workers)
docker compose -f docker-compose.production.yml up -d --scale backend=3
```

## Configuration Details

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOMAIN` | Your primary domain | - | Yes |
| `SITES` | Comma-separated list of sites for SSL | - | Yes |
| `LETSENCRYPT_EMAIL` | Email for SSL certificates | - | Yes |
| `DB_PASSWORD` | Database password | - | Yes |
| `ERPNEXT_VERSION` | ERPNext version tag | v15.77.0 | No |
| `HTTP_PUBLISH_PORT` | HTTP port | 80 | No |
| `HTTPS_PUBLISH_PORT` | HTTPS port | 443 | No |

### Resource Limits

The production setup includes optimized resource limits:

| Service | Memory Limit | Memory Reservation |
|---------|--------------|-------------------|
| Database | 2GB | 1GB |
| Backend | 2GB | 1GB |
| Frontend | 1GB | 512MB |
| Queue Workers | 1GB | 512MB |
| Redis | 512MB | 256MB |

### Health Checks

All services include comprehensive health checks:
- **Database:** MySQL ping check
- **Redis:** Redis ping check
- **Backend:** HTTP endpoint check
- **Frontend:** Static asset check
- **WebSocket:** Socket.IO endpoint check

## Security Considerations

### 1. Database Security
- Use strong, unique passwords
- Database is isolated in Docker network
- No external database ports exposed

### 2. SSL/TLS
- Automatic SSL certificate provisioning
- HTTP to HTTPS redirect
- Strong TLS configuration

### 3. Network Security
- Services communicate through isolated Docker network
- Only necessary ports exposed (80, 443)
- Real IP detection for accurate logging

### 4. Access Control
- Change default admin password immediately
- Consider setting up additional user accounts
- Regular security updates

## Backup and Recovery

### Automated Backups
```bash
# Create manual backup
./setup-production.sh backup yourdomain.com

# Set up automated daily backups (add to crontab)
0 2 * * * cd /path/to/frappe_docker && ./setup-production.sh backup yourdomain.com
```

### Backup Location
Backups are stored in the backend container at:
```
/home/frappe/frappe-bench/sites/{site-name}/private/backups/
```

### Recovery
```bash
# Access backend container
docker compose -f docker-compose.production.yml exec backend bash

# Restore from backup
bench --site yourdomain.com restore /path/to/backup/file.sql.gz
```

## Monitoring and Logging

### Log Management
Logs are configured with rotation to prevent disk space issues:
- Maximum log file size: 10MB
- Maximum log files: 3 per service
- Total log storage per service: ~30MB

### View Logs
```bash
# All services
./setup-production.sh logs

# Specific service
./setup-production.sh logs backend
./setup-production.sh logs db
./setup-production.sh logs proxy
```

### Resource Monitoring
```bash
# View current resource usage
./setup-production.sh status

# Detailed Docker stats
docker stats
```

## Troubleshooting

### Common Issues

**1. SSL Certificate Issues**
```bash
# Check certificate status
docker compose -f docker-compose.production.yml logs proxy

# Force certificate renewal
docker compose -f docker-compose.production.yml restart proxy
```

**2. Database Connection Issues**
```bash
# Check database health
docker compose -f docker-compose.production.yml exec db mysqladmin ping

# Check database logs
./setup-production.sh logs db
```

**3. Site Access Issues**
```bash
# Verify site creation
docker compose -f docker-compose.production.yml exec backend bench --site yourdomain.com doctor

# Check frontend logs
./setup-production.sh logs frontend
```

### Debug Mode
Enable debug logging for troubleshooting:
```bash
# Set debug log level in .env
TRAEFIK_LOG_LEVEL=DEBUG

# Restart services
./setup-production.sh restart
```

## Scaling and Performance

### Horizontal Scaling
```bash
# Scale backend workers
docker compose -f docker-compose.production.yml up -d --scale backend=3

# Scale queue workers
docker compose -f docker-compose.production.yml up -d --scale queue-short=2 --scale queue-long=2
```

### Database Optimization
The MariaDB configuration includes production optimizations:
- InnoDB buffer pool: 1GB
- Log file size: 256MB
- Optimized flush settings

### Redis Optimization
- Cache Redis: LRU eviction policy
- Queue Redis: Persistence enabled
- Memory limits configured

## Updates and Maintenance

### Regular Updates
```bash
# Update to latest stable version
./setup-production.sh update

# Update to specific version
# Edit ERPNEXT_VERSION in .env, then:
./setup-production.sh update
```

### Maintenance Windows
Plan maintenance during low-traffic periods:
1. Create backup
2. Update configuration if needed
3. Run update command
4. Verify all services are healthy
5. Test critical functionality

## Support and Resources

- **Official Documentation:** [Frappe Framework Documentation](https://frappeframework.com/docs)
- **ERPNext Documentation:** [ERPNext Documentation](https://docs.erpnext.com)
- **Docker Hub:** [Frappe Docker Images](https://hub.docker.com/u/frappe)
- **Community Forum:** [Frappe Forum](https://discuss.erpnext.com)

---

## License

This production setup configuration is provided under the same license as the Frappe Docker project.

---

*Last updated: December 2024*
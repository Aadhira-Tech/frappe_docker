#!/bin/bash
# Quick Start Example for Frappe Docker Production Setup
# This is a demonstration script - DO NOT run in production without customization

echo "🚀 Frappe Docker Production Setup - Quick Start Example"
echo "======================================================="
echo ""
echo "⚠️  WARNING: This is an example script for demonstration."
echo "    Please customize the settings before running in production!"
echo ""

# Configuration
DOMAIN="example.com"
EMAIL="admin@example.com"
DB_PASSWORD="secure_password_123"

echo "📋 Example Configuration:"
echo "   Domain: $DOMAIN"
echo "   Email: $EMAIL"
echo "   Database Password: [HIDDEN]"
echo ""

read -p "Do you want to continue with this example? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting. Please customize the configuration and try again."
    exit 1
fi

echo "🔧 Setting up environment..."

# Create .env file
cat > .env << EOF
# Production Environment Configuration
DOMAIN=$DOMAIN
SITES=\`$DOMAIN\`
LETSENCRYPT_EMAIL=$EMAIL
DB_PASSWORD=$DB_PASSWORD
ERPNEXT_VERSION=v15.77.0

# Optional settings
HTTP_PUBLISH_PORT=80
HTTPS_PUBLISH_PORT=443
TRAEFIK_DASHBOARD_PORT=8080
EOF

echo "✅ Environment file created"

echo "🔍 Validating configuration..."
./setup-production.sh validate

echo "🚀 Deploying production stack..."
./setup-production.sh deploy

echo "⏳ Waiting for services to start..."
sleep 60

echo "🌐 Creating site: $DOMAIN"
./setup-production.sh create-site "$DOMAIN"

echo "🎉 Setup complete!"
echo ""
echo "🌍 Your Frappe/ERPNext installation is available at:"
echo "   Main Site: https://$DOMAIN"
echo "   Traefik Dashboard: https://traefik.$DOMAIN:8080"
echo ""
echo "🔑 Default login credentials:"
echo "   Username: Administrator"
echo "   Password: admin"
echo ""
echo "⚠️  IMPORTANT: Change the default password immediately!"
echo ""
echo "📋 Management commands:"
echo "   ./setup-production.sh status   # Check service status"
echo "   ./setup-production.sh logs     # View logs"
echo "   ./health-check.sh              # Run health check"
echo "   make help                      # See all available commands"
echo ""
echo "📖 For more information, see PRODUCTION_SETUP.md"
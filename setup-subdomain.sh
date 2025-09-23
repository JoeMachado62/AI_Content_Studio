#!/bin/bash

# AI Content Studio - Subdomain Setup Script
# Configures the application for https://app.contentgenerator.me

echo "🚀 Setting up AI Content Studio for app.contentgenerator.me..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    echo "📦 Installing pnpm..."
    npm install -g pnpm
fi

echo "📋 Installing dependencies..."
pnpm install

echo "🐘 Starting PostgreSQL and Redis services..."
docker-compose -f docker-compose.dev.yaml up -d postiz-postgres postiz-redis

echo "⏳ Waiting for database to be ready..."
sleep 10

echo "🔧 Running database migrations..."
pnpm run prisma-db-push

echo "📝 Environment configuration:"
echo "  - Domain: https://app.contentgenerator.me"
echo "  - Database: PostgreSQL on localhost:5432"
echo "  - Redis: localhost:6379"
echo "  - Storage: Local file system"

echo ""
echo "🔑 SSL Certificate Setup Required:"
echo "  - Place SSL certificate at: ./ssl/app.contentgenerator.me.crt"
echo "  - Place SSL private key at: ./ssl/app.contentgenerator.me.key"
echo ""
echo "📊 Development Setup:"
echo "  - Run: pnpm run dev (for development)"
echo "  - Run: docker-compose -f docker-compose.subdomain.yaml up (for production-like setup)"
echo ""
echo "🌐 Access Points:"
echo "  - Frontend (dev): http://localhost:4200"
echo "  - Backend (dev): http://localhost:3000"
echo "  - Production: https://app.contentgenerator.me (after SSL setup)"
echo ""
echo "✅ Setup complete! Configure your domain DNS to point to this server."
echo "📚 Documentation: https://docs.postiz.com"
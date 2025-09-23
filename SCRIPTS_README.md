# AI Content Studio Management Scripts

This document explains how to use the management scripts for starting and managing the AI Content Studio application.

## Scripts Overview

### 1. Production Script (`start-production.sh`)
- **Purpose**: Start the application in production mode for `https://app.contentgenerator.me`
- **Features**:
  - Auto-restart functionality (restarts services if they crash)
  - Background monitoring daemon
  - Structured logging to files
  - Health checks and automatic recovery
  - Keep-alive mechanism (maximum 5 restart attempts per service)

### 2. Development Script (`start-development.sh`)
- **Purpose**: Start the application in development mode with real-time logging
- **Features**:
  - Real-time log output in terminal
  - Automatic hot-reload for code changes
  - Kills production processes before starting
  - No auto-restart (manual control for debugging)
  - Color-coded log output per service

## Usage

### Production Mode

```bash
# Start all services with auto-restart
./start-production.sh start

# Stop all services
./start-production.sh stop

# Restart all services
./start-production.sh restart

# Check service status
./start-production.sh status

# View specific service logs
./start-production.sh logs backend
./start-production.sh logs frontend
./start-production.sh logs workers
./start-production.sh logs cron
./start-production.sh logs main

# Show help
./start-production.sh help
```

### Development Mode

```bash
# Start all services in dev mode with real-time logs
./start-development.sh start

# Stop all services (dev and production)
./start-development.sh stop

# Kill only production processes
./start-development.sh kill-prod

# Restart development services
./start-development.sh restart

# Check service status
./start-development.sh status

# Show help
./start-development.sh help
```

## Service Architecture

The application consists of the following services:

1. **PostgreSQL** (Docker) - Database server
2. **Redis** (Docker) - Cache and queue server
3. **Backend** (Node.js) - NestJS API server
4. **Frontend** (Node.js) - Next.js web application
5. **Workers** (Node.js) - Background job processors
6. **Cron** (Node.js) - Scheduled task runner

## URLs

- **Production**: https://app.contentgenerator.me
- **Development Frontend**: http://localhost:4200
- **Development Backend**: http://localhost:3000

## Logs

### Production Logs
- Location: `/root/AI_Content_Studio/logs/`
- Files:
  - `main.log` - Main script activity
  - `backend.log` - Backend service logs
  - `frontend.log` - Frontend service logs
  - `workers.log` - Workers service logs
  - `cron.log` - Cron service logs
  - `postgres.log` - PostgreSQL startup logs
  - `redis.log` - Redis startup logs

### Development Logs
- Real-time output in terminal with color coding
- No persistent log files (for immediate feedback)

## Process Management

### PID Files
- Production: `/tmp/ai-content-studio/`
- Development: `/tmp/ai-content-studio/dev-*`

### Auto-Restart Behavior (Production Only)
- Services are monitored every 30 seconds
- Failed services are automatically restarted
- Maximum 5 restart attempts per service
- 10-second delay between restart attempts
- Monitoring stops if max attempts exceeded

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check what's using ports
   netstat -tlnp | grep -E "(3000|4200|5432|6379)"

   # Kill conflicting processes
   ./start-development.sh kill-prod
   ```

2. **Database Connection Issues**
   ```bash
   # Check Docker services
   docker ps

   # Restart Docker services
   docker-compose -f docker-compose.dev.yaml restart
   ```

3. **Permission Issues**
   ```bash
   # Ensure scripts are executable
   chmod +x start-production.sh start-development.sh
   ```

4. **Node.js Memory Issues**
   - Scripts automatically set `NODE_OPTIONS="--max-old-space-size=4096"`
   - Increase if you encounter out-of-memory errors

### Script Status Codes
- `0` - Success
- `1` - General error (service failed to start, already running, etc.)

### Stopping Services

To stop all services completely:
```bash
# Stop everything (production and development)
./start-development.sh stop

# Or stop only production
./start-production.sh stop
```

## Development Workflow

### Typical Development Session
1. Stop any running production services: `./start-development.sh kill-prod`
2. Start development mode: `./start-development.sh start`
3. Work on your code (changes will auto-reload)
4. Monitor real-time logs in terminal
5. Stop when done: `Ctrl+C`

### Switching to Production
1. Stop development: `Ctrl+C` or `./start-development.sh stop`
2. Start production: `./start-production.sh start`
3. Monitor with: `./start-production.sh status` and `./start-production.sh logs main`

## Advanced Usage

### Custom Environment Variables
Both scripts respect your `.env` file. Make sure to configure:
- `DATABASE_URL`
- `REDIS_URL`
- `FRONTEND_URL`
- `NEXT_PUBLIC_BACKEND_URL`
- Other required environment variables per `.env.example`

### Docker Services Only
If you need only database and Redis:
```bash
docker-compose -f docker-compose.dev.yaml up -d postiz-postgres postiz-redis
```

### Manual Service Control
You can also run individual services manually:
```bash
# Backend only
pnpm run dev:backend

# Frontend only
pnpm run dev:frontend

# Workers only
pnpm run dev:workers

# Cron only
pnpm run dev:cron
```
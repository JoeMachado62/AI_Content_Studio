#!/bin/bash

# AI Content Studio - Robust Startup Script
# Handles environment setup, health checks, and service management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
PID_DIR="/tmp/ai-content-studio"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
mkdir -p "$PID_DIR"

# Logging functions
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_DIR/startup.log"
}

log_info() {
    log "${BLUE}INFO${NC}" "$1"
}

log_warn() {
    log "${YELLOW}WARN${NC}" "$1"
}

log_error() {
    log "${RED}ERROR${NC}" "$1"
}

log_success() {
    log "${GREEN}SUCCESS${NC}" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for service to be ready
wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_attempts=${3:-30}
    local attempt=0

    log_info "Waiting for $service_name to be ready..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "$health_url" >/dev/null 2>&1; then
            log_success "$service_name is ready"
            return 0
        fi

        attempt=$((attempt + 1))
        log_info "Waiting for $service_name... ($attempt/$max_attempts)"
        sleep 2
    done

    log_error "$service_name failed to start within expected time"
    return 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()

    if ! command_exists node; then
        missing_deps+=("node")
    fi

    if ! command_exists pnpm; then
        missing_deps+=("pnpm")
    fi

    if ! command_exists docker; then
        missing_deps+=("docker")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi

    # Check Node.js version
    local node_version=$(node -v | cut -d'v' -f2)
    local required_version="20.0.0"

    if ! command_exists sort || [ "$(printf '%s\n' "$required_version" "$node_version" | sort -V | head -n1)" != "$required_version" ]; then
        log_warn "Node.js version $node_version might not be compatible. Recommended: v20+"
    fi

    log_success "Prerequisites check passed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."

    cd "$PROJECT_ROOT"

    # Create environment file hierarchy
    local env_files=(".env.prod.active" ".env.production" ".env")
    local env_found=false

    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            log_info "Found environment file: $env_file"
            env_found=true
            break
        fi
    done

    if [ "$env_found" = false ]; then
        if [ -f ".env.example" ]; then
            log_warn "No environment file found, copying from .env.example"
            cp .env.example .env
        else
            log_error "No environment configuration found"
            return 1
        fi
    fi

    # Load environment for validation
    if [ -f ".env.prod.active" ]; then
        source .env.prod.active
    elif [ -f ".env.production" ]; then
        source .env.production
    elif [ -f ".env" ]; then
        source .env
    fi

    # Validate critical environment variables
    local required_vars=("DATABASE_URL" "REDIS_URL" "JWT_SECRET")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    log_success "Environment setup completed"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."

    cd "$PROJECT_ROOT"

    if ! pnpm install --frozen-lockfile; then
        log_warn "Failed to install with frozen lockfile, trying regular install"
        pnpm install
    fi

    log_success "Dependencies installed"
}

# Start external services
start_external_services() {
    log_info "Starting external services..."

    cd "$PROJECT_ROOT"

    # Start PostgreSQL and Redis via Docker if not running
    if command_exists docker-compose || command_exists docker; then
        if [ -f "docker-compose.dev.yaml" ]; then
            log_info "Starting PostgreSQL and Redis via Docker Compose"
            docker-compose -f docker-compose.dev.yaml up -d postgres redis

            # Wait for PostgreSQL
            log_info "Waiting for PostgreSQL to be ready..."
            local pg_ready=false
            for i in {1..30}; do
                if docker-compose -f docker-compose.dev.yaml exec -T postgres pg_isready >/dev/null 2>&1; then
                    pg_ready=true
                    break
                fi
                sleep 2
            done

            if [ "$pg_ready" = false ]; then
                log_error "PostgreSQL failed to start"
                return 1
            fi

            log_success "External services started"
        else
            log_warn "No docker-compose.dev.yaml found, assuming external services are already running"
        fi
    else
        log_warn "Docker not available, assuming external services are already running"
    fi
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."

    cd "$PROJECT_ROOT"

    if ! pnpm run prisma-db-push; then
        log_error "Database migration failed"
        return 1
    fi

    log_success "Database migrations completed"
}

# Build application
build_application() {
    log_info "Building application..."

    cd "$PROJECT_ROOT"

    # Build backend
    log_info "Building backend..."
    if ! NODE_OPTIONS="--max-old-space-size=3072" pnpm run build:backend; then
        log_error "Backend build failed"
        return 1
    fi

    # Build frontend
    log_info "Building frontend..."
    if ! NODE_OPTIONS="--max-old-space-size=3072" pnpm run build:frontend; then
        log_error "Frontend build failed"
        return 1
    fi

    # Build workers
    log_info "Building workers..."
    if ! NODE_OPTIONS="--max-old-space-size=2048" pnpm run build:workers; then
        log_error "Workers build failed"
        return 1
    fi

    # Build cron
    log_info "Building cron..."
    if ! NODE_OPTIONS="--max-old-space-size=2048" pnpm run build:cron; then
        log_error "Cron build failed"
        return 1
    fi

    log_success "Application build completed"
}

# Start services
start_services() {
    log_info "Starting AI Content Studio services..."

    cd "$PROJECT_ROOT"

    # Kill existing PM2 processes if they exist
    if command_exists pm2; then
        pm2 delete all >/dev/null 2>&1 || true
    fi

    # Start backend
    log_info "Starting backend service..."
    pm2 start pnpm --name "ai-backend" -- run start:prod:backend

    # Wait for backend to be ready
    if ! wait_for_service "Backend" "http://localhost:3000/health/live" 30; then
        log_error "Backend failed to start"
        return 1
    fi

    # Start frontend
    log_info "Starting frontend service..."
    pm2 start pnpm --name "ai-frontend" -- run start:prod:frontend

    # Start workers
    log_info "Starting workers service..."
    pm2 start pnpm --name "ai-workers" -- run start:prod:workers

    # Start cron
    log_info "Starting cron service..."
    pm2 start pnpm --name "ai-cron" -- run start:prod:cron

    # Save PM2 configuration
    pm2 save

    log_success "All services started successfully"
}

# Perform health check
health_check() {
    log_info "Performing health check..."

    # Check backend health
    if ! curl -f -s "http://localhost:3000/health" >/dev/null; then
        log_error "Backend health check failed"
        return 1
    fi

    # Check frontend (if applicable)
    if ! curl -f -s "http://localhost:4200" >/dev/null 2>&1; then
        log_warn "Frontend health check failed (this might be normal if using reverse proxy)"
    fi

    log_success "Health check passed"
}

# Display service status
show_status() {
    log_info "Service Status:"

    if command_exists pm2; then
        pm2 status
    fi

    echo
    log_info "Application URLs:"
    echo "  - Backend API: http://localhost:3000"
    echo "  - Health Check: http://localhost:3000/health"
    echo "  - Detailed Health: http://localhost:3000/health/detailed"
    echo "  - Frontend: http://localhost:4200"
    echo
    log_info "Logs location: $LOG_DIR"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."

    if [ -f "$PID_DIR/startup.pid" ]; then
        rm -f "$PID_DIR/startup.pid"
    fi
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Main execution
main() {
    local start_time=$(date +%s)

    log_info "Starting AI Content Studio startup sequence..."
    echo "$$" > "$PID_DIR/startup.pid"

    # Execute startup steps
    check_prerequisites
    setup_environment
    install_dependencies
    start_external_services
    run_migrations
    build_application
    start_services
    health_check

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "AI Content Studio startup completed successfully in ${duration}s"

    show_status
}

# Execute main function
main "$@"
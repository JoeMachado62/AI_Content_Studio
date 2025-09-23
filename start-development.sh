#!/bin/bash

# AI Content Studio - Development Startup Script
# This script starts the application in development mode with real-time logging
# It can also kill processes started by the production script

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
APP_NAME="ai-content-studio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="/tmp/${APP_NAME}"
PROD_PID_DIR="/tmp/${APP_NAME}"

# Create necessary directories
mkdir -p "${PID_DIR}"

# PID file locations (for development processes)
DEV_POSTGRES_PID="${PID_DIR}/dev-postgres.pid"
DEV_REDIS_PID="${PID_DIR}/dev-redis.pid"
DEV_BACKEND_PID="${PID_DIR}/dev-backend.pid"
DEV_FRONTEND_PID="${PID_DIR}/dev-frontend.pid"
DEV_WORKERS_PID="${PID_DIR}/dev-workers.pid"
DEV_CRON_PID="${PID_DIR}/dev-cron.pid"

# Production PID file locations (for killing production processes)
PROD_POSTGRES_PID="${PROD_PID_DIR}/postgres.pid"
PROD_REDIS_PID="${PROD_PID_DIR}/redis.pid"
PROD_BACKEND_PID="${PROD_PID_DIR}/backend.pid"
PROD_FRONTEND_PID="${PROD_PID_DIR}/frontend.pid"
PROD_WORKERS_PID="${PROD_PID_DIR}/workers.pid"
PROD_CRON_PID="${PROD_PID_DIR}/cron.pid"

# Function to log messages with service colors
log() {
    local service=$1
    local level=$2
    shift 2
    local message="$@"
    local timestamp=$(date '+%H:%M:%S')

    # Service-specific colors
    case $service in
        "MAIN") color="${BLUE}" ;;
        "POSTGRES") color="${GREEN}" ;;
        "REDIS") color="${RED}" ;;
        "BACKEND") color="${YELLOW}" ;;
        "FRONTEND") color="${CYAN}" ;;
        "WORKERS") color="${PURPLE}" ;;
        "CRON") color="${GREEN}" ;;
        "SYSTEM") color="${BLUE}" ;;
        *) color="${NC}" ;;
    esac

    echo -e "${color}[${timestamp}] [${service}]${NC} $message"
}

# Function to check if process is running
is_process_running() {
    local pid_file=$1
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Function to stop a process
stop_process() {
    local pid_file=$1
    local service_name=$2

    if is_process_running "$pid_file"; then
        local pid=$(cat "$pid_file")
        log "SYSTEM" "INFO" "Stopping $service_name (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null || true

        # Wait for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$pid" 2>/dev/null; then
                rm -f "$pid_file"
                log "SYSTEM" "INFO" "$service_name stopped gracefully"
                return 0
            fi
            sleep 1
        done

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log "SYSTEM" "WARN" "Force killing $service_name..."
            kill -KILL "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    fi
}

# Function to kill all production processes
kill_production_processes() {
    log "SYSTEM" "INFO" "Checking for and stopping production processes..."

    local killed_any=false

    # Stop production Node.js services
    prod_services=("Cron:$PROD_CRON_PID" "Workers:$PROD_WORKERS_PID" "Frontend:$PROD_FRONTEND_PID" "Backend:$PROD_BACKEND_PID")

    for service_info in "${prod_services[@]}"; do
        IFS=':' read -r service_name pid_file <<< "$service_info"
        if is_process_running "$pid_file"; then
            stop_process "$pid_file" "Production $service_name"
            killed_any=true
        fi
    done

    # Stop production Docker services
    if is_process_running "$PROD_POSTGRES_PID"; then
        log "SYSTEM" "INFO" "Stopping production Docker services..."
        cd "$SCRIPT_DIR"
        docker-compose -f docker-compose.dev.yaml down >/dev/null 2>&1 || true
        rm -f "$PROD_POSTGRES_PID"
        killed_any=true
    fi

    # Kill any remaining processes by name (fallback)
    local node_processes=$(pgrep -f "pnpm.*start:prod" 2>/dev/null || true)
    if [[ -n "$node_processes" ]]; then
        log "SYSTEM" "WARN" "Found additional production processes, killing them..."
        echo "$node_processes" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        echo "$node_processes" | xargs kill -KILL 2>/dev/null || true
        killed_any=true
    fi

    if [[ "$killed_any" == "true" ]]; then
        log "SYSTEM" "INFO" "Production processes stopped"
    else
        log "SYSTEM" "INFO" "No production processes found running"
    fi
}

# Function to start Docker services
start_docker_services() {
    log "POSTGRES" "INFO" "Starting Docker services (PostgreSQL and Redis)..."

    cd "$SCRIPT_DIR"

    # Start Docker services
    docker-compose -f docker-compose.dev.yaml up -d postiz-postgres postiz-redis >/dev/null 2>&1
    echo $$ > "$DEV_POSTGRES_PID"  # Store this script's PID as a marker

    # Wait for services to be ready
    log "POSTGRES" "INFO" "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker exec postiz-postgres pg_isready -U postiz-local -d postiz-db-local >/dev/null 2>&1; then
            log "POSTGRES" "INFO" "PostgreSQL is ready"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log "POSTGRES" "ERROR" "PostgreSQL failed to start after 30 seconds"
            return 1
        fi
        sleep 1
    done

    log "REDIS" "INFO" "Waiting for Redis to be ready..."
    for i in {1..30}; do
        if docker exec postiz-redis redis-cli ping >/dev/null 2>&1; then
            log "REDIS" "INFO" "Redis is ready"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log "REDIS" "ERROR" "Redis failed to start after 30 seconds"
            return 1
        fi
        sleep 1
    done
}

# Function to setup development environment
setup_dev_environment() {
    log "SYSTEM" "INFO" "Setting up development environment..."

    cd "$SCRIPT_DIR"

    # Copy development environment if it exists
    if [[ -f ".env.development" ]]; then
        log "SYSTEM" "INFO" "Using development environment configuration"
        cp .env.development .env.dev.active
    else
        log "SYSTEM" "WARN" "No .env.development found, using existing .env"
        cp .env .env.dev.active
    fi

    # Ensure development ports are set correctly
    if ! grep -q "PORT=3000" .env.dev.active; then
        echo "PORT=3000" >> .env.dev.active
    fi

    # Only override URLs if they're not already set to production domains
    if grep -q "NEXT_PUBLIC_BACKEND_URL.*localhost" .env.dev.active; then
        sed -i 's|NEXT_PUBLIC_BACKEND_URL=.*|NEXT_PUBLIC_BACKEND_URL="http://localhost:3000"|' .env.dev.active
    fi
    if grep -q "BACKEND_INTERNAL_URL.*localhost" .env.dev.active || ! grep -q "BACKEND_INTERNAL_URL" .env.dev.active; then
        if ! grep -q "BACKEND_INTERNAL_URL" .env.dev.active; then
            echo 'BACKEND_INTERNAL_URL="http://localhost:3000"' >> .env.dev.active
        else
            sed -i 's|BACKEND_INTERNAL_URL=.*|BACKEND_INTERNAL_URL="http://localhost:3000"|' .env.dev.active
        fi
    fi
    if grep -q "FRONTEND_URL.*localhost" .env.dev.active; then
        sed -i 's|FRONTEND_URL=.*|FRONTEND_URL="http://localhost:4200"|' .env.dev.active
    fi
}

# Function to start a development service with real-time logging
start_dev_service() {
    local service_name=$1
    local pid_file=$2
    local command=$3
    local log_prefix=$4

    log "$log_prefix" "INFO" "Starting $service_name in development mode..."

    cd "$SCRIPT_DIR"

    # Use development environment
    set -a
    source .env.dev.active
    set +a

    # Start the service and capture its output
    {
        eval "$command" 2>&1 | while IFS= read -r line; do
            log "$log_prefix" "LOG" "$line"
        done
    } &

    local pid=$!
    echo $pid > "$pid_file"

    # Give service time to start
    sleep 3

    if is_process_running "$pid_file"; then
        log "$log_prefix" "INFO" "$service_name started successfully (PID: $pid)"
        return 0
    else
        log "$log_prefix" "ERROR" "$service_name failed to start"
        return 1
    fi
}

# Function to stop all development services
stop_all_dev_services() {
    log "SYSTEM" "INFO" "Stopping all development services..."

    stop_process "$DEV_CRON_PID" "Development Cron"
    stop_process "$DEV_WORKERS_PID" "Development Workers"
    stop_process "$DEV_FRONTEND_PID" "Development Frontend"
    stop_process "$DEV_BACKEND_PID" "Development Backend"

    # Stop Docker services
    if is_process_running "$DEV_POSTGRES_PID"; then
        log "SYSTEM" "INFO" "Stopping Docker services..."
        cd "$SCRIPT_DIR"
        docker-compose -f docker-compose.dev.yaml down >/dev/null 2>&1 || true
        rm -f "$DEV_POSTGRES_PID"
    fi

    # Clean up development environment file
    if [[ -f "$SCRIPT_DIR/.env.dev.active" ]]; then
        rm -f "$SCRIPT_DIR/.env.dev.active"
    fi

    log "SYSTEM" "INFO" "All development services stopped"
}

# Function to show service status
show_status() {
    echo -e "\n${BLUE}=== AI Content Studio Development Status ===${NC}"

    echo -e "\n${YELLOW}Docker Services:${NC}"
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(postiz-postgres|postiz-redis)" >/dev/null 2>&1; then
        docker ps --format "table {{.Names}}\t{{.Status}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(postiz-postgres|postiz-redis)"
    else
        echo "No Docker services running"
    fi

    echo -e "\n${YELLOW}Development Services:${NC}"
    printf "%-10s %-8s %-10s\n" "Service" "Status" "PID"
    printf "%-10s %-8s %-10s\n" "-------" "------" "---"

    dev_services=("Backend:$DEV_BACKEND_PID" "Frontend:$DEV_FRONTEND_PID" "Workers:$DEV_WORKERS_PID" "Cron:$DEV_CRON_PID")

    for service_info in "${dev_services[@]}"; do
        IFS=':' read -r service_name pid_file <<< "$service_info"
        if is_process_running "$pid_file"; then
            pid=$(cat "$pid_file")
            printf "%-10s ${GREEN}%-8s${NC} %-10s\n" "$service_name" "Running" "$pid"
        else
            printf "%-10s ${RED}%-8s${NC} %-10s\n" "$service_name" "Stopped" "-"
        fi
    done

    echo -e "\n${YELLOW}Application URLs:${NC}"
    echo -e "Frontend (Dev): http://localhost:4200"
    echo -e "Backend API:    http://localhost:3000"
    echo -e "Production URL: https://app.contentgenerator.me"
}

# Function to monitor services and show real-time logs
monitor_services() {
    log "SYSTEM" "INFO" "Development mode active - Real-time logging enabled"
    log "SYSTEM" "INFO" "Press Ctrl+C to stop all services"
    echo ""

    # Wait for all services to start
    sleep 5

    # Monitor services (simplified for development)
    while true; do
        sleep 10

        # Check if any service died
        services_to_check=("Backend:$DEV_BACKEND_PID:BACKEND" "Frontend:$DEV_FRONTEND_PID:FRONTEND" "Workers:$DEV_WORKERS_PID:WORKERS" "Cron:$DEV_CRON_PID:CRON")

        for service_info in "${services_to_check[@]}"; do
            IFS=':' read -r service_name pid_file log_prefix <<< "$service_info"
            if ! is_process_running "$pid_file"; then
                log "$log_prefix" "ERROR" "$service_name has stopped unexpectedly"
            fi
        done
    done
}

# Signal handlers
cleanup() {
    echo ""
    log "SYSTEM" "INFO" "Received shutdown signal, cleaning up..."
    stop_all_dev_services
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
case "${1:-start}" in
    "start")
        log "MAIN" "INFO" "Starting AI Content Studio in development mode..."

        # Kill any production processes first
        kill_production_processes

        # Check if already running
        if is_process_running "$DEV_BACKEND_PID" || is_process_running "$DEV_FRONTEND_PID"; then
            log "MAIN" "ERROR" "Development services appear to already be running. Use 'stop' first or 'restart'."
            exit 1
        fi

        # Setup development environment
        setup_dev_environment

        # Ensure dependencies are installed
        log "MAIN" "INFO" "Installing dependencies (this may take 30-60 seconds)..."
        cd "$SCRIPT_DIR"
        pnpm install --reporter=silent

        # Start services in order
        start_docker_services || exit 1

        # Apply database migrations
        log "MAIN" "INFO" "Applying database migrations..."
        set -a
        source .env.dev.active
        set +a
        pnpm run prisma-db-push --accept-data-loss >/dev/null 2>&1 || {
            log "MAIN" "ERROR" "Database migration failed. Check your database connection."
            stop_all_dev_services
            exit 1
        }

        # Start Node.js services in development mode with real-time logging
        start_dev_service "Backend" "$DEV_BACKEND_PID" "NODE_OPTIONS='--max-old-space-size=4096' pnpm run dev:backend" "BACKEND" &
        sleep 3  # Give backend time to start

        start_dev_service "Workers" "$DEV_WORKERS_PID" "pnpm run dev:workers" "WORKERS" &
        start_dev_service "Cron" "$DEV_CRON_PID" "pnpm run dev:cron" "CRON" &
        start_dev_service "Frontend" "$DEV_FRONTEND_PID" "pnpm run dev:frontend" "FRONTEND" &

        # Wait for all background jobs to start
        wait

        log "MAIN" "INFO" "All development services started!"
        show_status
        echo ""

        # Start monitoring
        monitor_services
        ;;

    "stop")
        kill_production_processes
        stop_all_dev_services
        ;;

    "kill-prod"|"kill-production")
        kill_production_processes
        ;;

    "restart")
        kill_production_processes
        stop_all_dev_services
        sleep 3
        exec "$0" start
        ;;

    "status")
        show_status
        ;;

    "help"|"--help"|"-h")
        echo "AI Content Studio Development Manager"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start          - Start all services in development mode with real-time logs (default)"
        echo "  stop           - Stop all development services and production processes"
        echo "  kill-prod      - Kill only production processes"
        echo "  restart        - Restart all development services"
        echo "  status         - Show service status"
        echo "  help           - Show this help message"
        echo ""
        echo "Development Features:"
        echo "  • Real-time log output in terminal"
        echo "  • Automatic hot-reload for code changes"
        echo "  • Kills production processes before starting"
        echo "  • No auto-restart (manual control)"
        echo ""
        echo "Development URLs:"
        echo "  Frontend: http://localhost:4200"
        echo "  Backend:  http://localhost:3000"
        echo ""
        echo "Production URL: https://app.contentgenerator.me"
        ;;

    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
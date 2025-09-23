#!/bin/bash

# AI Content Studio - Production Startup Script with Auto-Restart
# This script starts the application in production mode with automatic restart capability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="ai-content-studio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="/tmp/${APP_NAME}"
LOG_DIR="${SCRIPT_DIR}/logs"
MAX_RESTART_ATTEMPTS=5
RESTART_DELAY=10

# Create necessary directories
mkdir -p "${PID_DIR}" "${LOG_DIR}"

# PID file locations
POSTGRES_PID="${PID_DIR}/postgres.pid"
REDIS_PID="${PID_DIR}/redis.pid"
BACKEND_PID="${PID_DIR}/backend.pid"
FRONTEND_PID="${PID_DIR}/frontend.pid"
WORKERS_PID="${PID_DIR}/workers.pid"
CRON_PID="${PID_DIR}/cron.pid"

# Log file locations
POSTGRES_LOG="${LOG_DIR}/postgres.log"
REDIS_LOG="${LOG_DIR}/redis.log"
BACKEND_LOG="${LOG_DIR}/backend.log"
FRONTEND_LOG="${LOG_DIR}/frontend.log"
WORKERS_LOG="${LOG_DIR}/workers.log"
CRON_LOG="${LOG_DIR}/cron.log"
MAIN_LOG="${LOG_DIR}/main.log"

# Function to log messages
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${GREEN}[${timestamp}] [INFO]${NC} $message" | tee -a "${MAIN_LOG}"
            ;;
        "WARN")
            echo -e "${YELLOW}[${timestamp}] [WARN]${NC} $message" | tee -a "${MAIN_LOG}"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] [ERROR]${NC} $message" | tee -a "${MAIN_LOG}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[${timestamp}] [DEBUG]${NC} $message" | tee -a "${MAIN_LOG}"
            ;;
    esac
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
        log "INFO" "Stopping $service_name (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null || true

        # Wait for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$pid" 2>/dev/null; then
                rm -f "$pid_file"
                log "INFO" "$service_name stopped gracefully"
                return 0
            fi
            sleep 1
        done

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log "WARN" "Force killing $service_name..."
            kill -KILL "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    fi
}

# Function to start Docker services
start_docker_services() {
    log "INFO" "Starting Docker services (PostgreSQL and Redis)..."

    cd "$SCRIPT_DIR"

    # Start Docker services
    docker-compose -f docker-compose.dev.yaml up -d postiz-postgres postiz-redis >> "$POSTGRES_LOG" 2>&1 &
    echo $! > "$POSTGRES_PID"

    # Wait for services to be ready
    log "INFO" "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker exec postiz-postgres pg_isready -U postiz-local -d postiz-db-local >/dev/null 2>&1; then
            log "INFO" "PostgreSQL is ready"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log "ERROR" "PostgreSQL failed to start after 30 seconds"
            return 1
        fi
        sleep 1
    done

    log "INFO" "Waiting for Redis to be ready..."
    for i in {1..30}; do
        if docker exec postiz-redis redis-cli ping >/dev/null 2>&1; then
            log "INFO" "Redis is ready"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log "ERROR" "Redis failed to start after 30 seconds"
            return 1
        fi
        sleep 1
    done
}

# Function to start a Node.js service
start_node_service() {
    local service_name=$1
    local pid_file=$2
    local log_file=$3
    local command=$4

    log "INFO" "Starting $service_name..."

    cd "$SCRIPT_DIR"

    # Use production environment
    set -a
    source .env.prod.active
    set +a

    # Start the service in background
    nohup bash -c "$command" > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"

    # Check if service started successfully
    sleep 3
    if is_process_running "$pid_file"; then
        log "INFO" "$service_name started successfully (PID: $pid)"
        return 0
    else
        log "ERROR" "$service_name failed to start"
        return 1
    fi
}

# Function to monitor and restart services
monitor_services() {
    local restart_counts=()

    # Initialize restart counters
    restart_counts[0]=0 # Backend
    restart_counts[1]=0 # Frontend
    restart_counts[2]=0 # Workers
    restart_counts[3]=0 # Cron

    while true; do
        sleep 30  # Check every 30 seconds

        # Check backend
        if ! is_process_running "$BACKEND_PID"; then
            if [[ ${restart_counts[0]} -lt $MAX_RESTART_ATTEMPTS ]]; then
                log "WARN" "Backend crashed, restarting... (attempt $((${restart_counts[0]} + 1))/$MAX_RESTART_ATTEMPTS)"
                start_node_service "Backend" "$BACKEND_PID" "$BACKEND_LOG" "NODE_OPTIONS='--max-old-space-size=4096' pnpm run start:prod:backend"
                restart_counts[0]=$((${restart_counts[0]} + 1))
                sleep $RESTART_DELAY
            else
                log "ERROR" "Backend exceeded maximum restart attempts, stopping monitoring"
                break
            fi
        else
            restart_counts[0]=0  # Reset counter on successful health check
        fi

        # Check frontend
        if ! is_process_running "$FRONTEND_PID"; then
            if [[ ${restart_counts[1]} -lt $MAX_RESTART_ATTEMPTS ]]; then
                log "WARN" "Frontend crashed, restarting... (attempt $((${restart_counts[1]} + 1))/$MAX_RESTART_ATTEMPTS)"
                start_node_service "Frontend" "$FRONTEND_PID" "$FRONTEND_LOG" "pnpm run start:prod:frontend"
                restart_counts[1]=$((${restart_counts[1]} + 1))
                sleep $RESTART_DELAY
            else
                log "ERROR" "Frontend exceeded maximum restart attempts, stopping monitoring"
                break
            fi
        else
            restart_counts[1]=0  # Reset counter on successful health check
        fi

        # Check workers
        if ! is_process_running "$WORKERS_PID"; then
            if [[ ${restart_counts[2]} -lt $MAX_RESTART_ATTEMPTS ]]; then
                log "WARN" "Workers crashed, restarting... (attempt $((${restart_counts[2]} + 1))/$MAX_RESTART_ATTEMPTS)"
                start_node_service "Workers" "$WORKERS_PID" "$WORKERS_LOG" "pnpm run start:prod:workers"
                restart_counts[2]=$((${restart_counts[2]} + 1))
                sleep $RESTART_DELAY
            else
                log "ERROR" "Workers exceeded maximum restart attempts, stopping monitoring"
                break
            fi
        else
            restart_counts[2]=0  # Reset counter on successful health check
        fi

        # Check cron
        if ! is_process_running "$CRON_PID"; then
            if [[ ${restart_counts[3]} -lt $MAX_RESTART_ATTEMPTS ]]; then
                log "WARN" "Cron crashed, restarting... (attempt $((${restart_counts[3]} + 1))/$MAX_RESTART_ATTEMPTS)"
                start_node_service "Cron" "$CRON_PID" "$CRON_LOG" "pnpm run start:prod:cron"
                restart_counts[3]=$((${restart_counts[3]} + 1))
                sleep $RESTART_DELAY
            else
                log "ERROR" "Cron exceeded maximum restart attempts, stopping monitoring"
                break
            fi
        else
            restart_counts[3]=0  # Reset counter on successful health check
        fi
    done
}

# Function to stop all services
stop_all_services() {
    log "INFO" "Stopping all services..."

    stop_process "$CRON_PID" "Cron"
    stop_process "$WORKERS_PID" "Workers"
    stop_process "$FRONTEND_PID" "Frontend"
    stop_process "$BACKEND_PID" "Backend"

    # Stop Docker services
    if is_process_running "$POSTGRES_PID"; then
        log "INFO" "Stopping Docker services..."
        cd "$SCRIPT_DIR"
        docker-compose -f docker-compose.dev.yaml down >/dev/null 2>&1 || true
        rm -f "$POSTGRES_PID"
    fi

    # Clean up production environment file
    if [[ -f "$SCRIPT_DIR/.env.prod.active" ]]; then
        rm -f "$SCRIPT_DIR/.env.prod.active"
    fi

    log "INFO" "All services stopped"
}

# Function to show service status
show_status() {
    echo -e "\n${BLUE}=== AI Content Studio Status ===${NC}"

    echo -e "\n${YELLOW}Docker Services:${NC}"
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(postiz-postgres|postiz-redis)" >/dev/null 2>&1; then
        docker ps --format "table {{.Names}}\t{{.Status}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(postiz-postgres|postiz-redis)"
    else
        echo "No Docker services running"
    fi

    echo -e "\n${YELLOW}Node.js Services:${NC}"
    printf "%-10s %-8s %-10s\n" "Service" "Status" "PID"
    printf "%-10s %-8s %-10s\n" "-------" "------" "---"

    services=("Backend:$BACKEND_PID" "Frontend:$FRONTEND_PID" "Workers:$WORKERS_PID" "Cron:$CRON_PID")

    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name pid_file <<< "$service_info"
        if is_process_running "$pid_file"; then
            pid=$(cat "$pid_file")
            printf "%-10s ${GREEN}%-8s${NC} %-10s\n" "$service_name" "Running" "$pid"
        else
            printf "%-10s ${RED}%-8s${NC} %-10s\n" "$service_name" "Stopped" "-"
        fi
    done

    echo -e "\n${YELLOW}Application URL:${NC} https://app.contentgenerator.me"
    echo -e "${YELLOW}Log Directory:${NC} $LOG_DIR"
}

# Signal handlers
cleanup() {
    log "INFO" "Received shutdown signal, cleaning up..."
    stop_all_services
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
case "${1:-start}" in
    "start")
        log "INFO" "Starting AI Content Studio in production mode..."

        # Check if already running
        if is_process_running "$BACKEND_PID" || is_process_running "$FRONTEND_PID"; then
            log "ERROR" "Application appears to already be running. Use 'stop' first or 'restart'."
            exit 1
        fi

        # Setup production environment
        log "INFO" "Setting up production environment..."
        cd "$SCRIPT_DIR"

        # Use production environment if it exists
        if [[ -f ".env.production" ]]; then
            log "INFO" "Using production environment configuration"
            cp .env.production .env.prod.active
        else
            log "WARN" "No .env.production found, using existing .env"
            cp .env .env.prod.active
        fi

        # Ensure dependencies are installed and built
        log "INFO" "Installing dependencies (this may take 30-60 seconds)..."
        pnpm install --reporter=silent

        log "INFO" "Building application..."
        pnpm run build >> "$MAIN_LOG" 2>&1 || {
            log "ERROR" "Build failed. Check $MAIN_LOG for details."
            exit 1
        }

        # Start services in order
        start_docker_services || exit 1

        # Apply database migrations
        log "INFO" "Applying database migrations..."
        set -a
        source .env.prod.active
        set +a
        pnpm run prisma-db-push --accept-data-loss >> "$MAIN_LOG" 2>&1 || {
            log "ERROR" "Database migration failed. Check your database connection and $MAIN_LOG for details."
            stop_all_services
            exit 1
        }

        # Start Node.js services
        start_node_service "Backend" "$BACKEND_PID" "$BACKEND_LOG" "NODE_OPTIONS='--max-old-space-size=4096' pnpm run start:prod:backend" || exit 1
        sleep 5  # Give backend time to start

        start_node_service "Workers" "$WORKERS_PID" "$WORKERS_LOG" "pnpm run start:prod:workers" || exit 1
        start_node_service "Cron" "$CRON_PID" "$CRON_LOG" "pnpm run start:prod:cron" || exit 1
        start_node_service "Frontend" "$FRONTEND_PID" "$FRONTEND_LOG" "pnpm run start:prod:frontend" || exit 1

        log "INFO" "All services started successfully!"
        show_status

        log "INFO" "Starting monitoring daemon (auto-restart enabled)..."
        log "INFO" "Press Ctrl+C to stop all services"

        # Start monitoring in background
        monitor_services
        ;;

    "stop")
        stop_all_services
        ;;

    "restart")
        stop_all_services
        sleep 5
        exec "$0" start
        ;;

    "status")
        show_status
        ;;

    "logs")
        if [[ -n "$2" ]]; then
            case "$2" in
                "backend"|"be") tail -f "$BACKEND_LOG" ;;
                "frontend"|"fe") tail -f "$FRONTEND_LOG" ;;
                "workers"|"work") tail -f "$WORKERS_LOG" ;;
                "cron") tail -f "$CRON_LOG" ;;
                "main") tail -f "$MAIN_LOG" ;;
                *) echo "Available logs: backend, frontend, workers, cron, main" ;;
            esac
        else
            echo "Usage: $0 logs [backend|frontend|workers|cron|main]"
        fi
        ;;

    "help"|"--help"|"-h")
        echo "AI Content Studio Production Manager"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services with auto-restart (default)"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  status   - Show service status"
        echo "  logs     - View logs (specify: backend, frontend, workers, cron, main)"
        echo "  help     - Show this help message"
        echo ""
        echo "The application will be available at: https://app.contentgenerator.me"
        ;;

    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
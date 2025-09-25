#!/bin/bash

# AI Content Studio - Health Check Script
# Quick script to verify all services are running properly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKEND_URL="http://localhost:3000"
FRONTEND_URL="http://localhost:4200"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check service health
check_service() {
    local service_name=$1
    local url=$2
    local required=${3:-true}

    log_info "Checking $service_name..."

    if curl -f -s "$url" >/dev/null 2>&1; then
        log_success "$service_name is healthy"
        return 0
    else
        if [ "$required" = "true" ]; then
            log_error "$service_name is not responding"
            return 1
        else
            log_warn "$service_name is not responding (optional)"
            return 0
        fi
    fi
}

# Check detailed backend health
check_backend_detailed() {
    log_info "Checking detailed backend health..."

    local health_data
    if health_data=$(curl -s "$BACKEND_URL/health/detailed" 2>/dev/null); then
        local status=$(echo "$health_data" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$status" = "ok" ]; then
            log_success "Backend detailed health check passed"

            # Extract key metrics
            local uptime=$(echo "$health_data" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2)
            local memory_used=$(echo "$health_data" | grep -o '"used":[0-9]*' | cut -d':' -f2)

            echo "  - Uptime: ${uptime}s"
            echo "  - Memory used: ${memory_used}MB"
            return 0
        else
            log_error "Backend status: $status"
            return 1
        fi
    else
        log_error "Could not retrieve detailed health information"
        return 1
    fi
}

# Check PM2 processes
check_pm2() {
    if command -v pm2 >/dev/null 2>&1; then
        log_info "Checking PM2 processes..."

        local pm2_output
        pm2_output=$(pm2 jlist 2>/dev/null || echo "[]")

        local online_processes
        online_processes=$(echo "$pm2_output" | grep -c '"status":"online"' || echo "0")

        if [ "$online_processes" -gt 0 ]; then
            log_success "$online_processes PM2 processes are online"
            echo "$pm2_output" | grep -E '"name"|"status"|"uptime"' | head -20
            return 0
        else
            log_error "No PM2 processes are online"
            return 1
        fi
    else
        log_warn "PM2 not found, skipping process check"
        return 0
    fi
}

# Check system resources
check_resources() {
    log_info "Checking system resources..."

    # Memory check
    local memory_info
    memory_info=$(free -m)
    local available_memory
    available_memory=$(echo "$memory_info" | awk 'NR==2{print $7}')

    if [ "$available_memory" -lt 500 ]; then
        log_warn "Low available memory: ${available_memory}MB"
    else
        log_success "Available memory: ${available_memory}MB"
    fi

    # Disk space check
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')

    if [ "$disk_usage" -gt 90 ]; then
        log_error "High disk usage: ${disk_usage}%"
        return 1
    elif [ "$disk_usage" -gt 80 ]; then
        log_warn "Moderate disk usage: ${disk_usage}%"
    else
        log_success "Disk usage: ${disk_usage}%"
    fi

    # Load average
    local load_avg
    load_avg=$(uptime | grep -o 'load average: [0-9.]*' | cut -d' ' -f3)
    log_info "Load average: $load_avg"

    return 0
}

# Check external dependencies
check_external_deps() {
    log_info "Checking external dependencies..."

    # Check PostgreSQL
    if docker ps --format "table {{.Names}}" | grep -q postgres; then
        log_success "PostgreSQL container is running"
    else
        log_error "PostgreSQL container not found"
        return 1
    fi

    # Check Redis
    if docker ps --format "table {{.Names}}" | grep -q redis; then
        log_success "Redis container is running"
    else
        log_error "Redis container not found"
        return 1
    fi

    return 0
}

# Main health check
main() {
    echo "=== AI Content Studio Health Check ==="
    echo "Timestamp: $(date)"
    echo

    local overall_status=0

    # Core service checks
    check_service "Backend API" "$BACKEND_URL/health" || overall_status=1
    check_service "Frontend" "$FRONTEND_URL" false || true

    # Detailed checks
    check_backend_detailed || overall_status=1
    check_pm2 || overall_status=1
    check_external_deps || overall_status=1
    check_resources || overall_status=1

    echo
    echo "=== Health Check Summary ==="

    if [ $overall_status -eq 0 ]; then
        log_success "All health checks passed"
        echo
        echo "Services are running optimally ✅"
        exit 0
    else
        log_error "Some health checks failed"
        echo
        echo "Issues detected that require attention ⚠️"
        exit 1
    fi
}

# Execute main function
main "$@"
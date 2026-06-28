#!/bin/bash

# PHP-FPM Configuration Calculator
# Automatically calculates optimal PHP-FPM settings based on system resources
# Usage: ./php-fpm-calculator.sh [--verbose]

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Default values
FPM_MEM=50
TOTAL_RAM=0
CPU_CORES=1
VERBOSE=false

# Parse arguments
if [[ "${1:-}" == "--verbose" ]] || [[ "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

echo -e "${CYAN}=== PHP-FPM Configuration Calculator ===${NC}"
echo ""

# Get total RAM with proper error checking
if command -v free > /dev/null 2>&1; then
    TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    if [[ -z "$TOTAL_RAM" ]] || [[ "$TOTAL_RAM" == "0" ]]; then
        TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    fi
fi

# Fallback: try /proc/meminfo if free command didn't work
if [[ -z "$TOTAL_RAM" ]] || [[ "$TOTAL_RAM" == "0" ]]; then
    if [[ -f /proc/meminfo ]]; then
        TOTAL_RAM=$(awk '/^MemTotal:/{printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
    fi
fi

# Final fallback
if [[ -z "$TOTAL_RAM" ]] || [[ "$TOTAL_RAM" == "0" ]]; then
    echo -e "${RED}Error:${NC} Cannot detect total RAM"
    echo "Debug: Trying to read memory..."
    free -m 2>&1 || echo "free command not available"
    exit 1
fi

# Get CPU cores
if command -v nproc > /dev/null 2>&1; then
    CPU_CORES=$(nproc 2>/dev/null || echo 1)
else
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
fi

[[ "$VERBOSE" == true ]] && echo -e "${GREEN}✓${NC} System: ${TOTAL_RAM}MB RAM, ${CPU_CORES} CPU cores"

# Detect and measure PHP-FPM processes
FPM_PIDS=$(pgrep -x "php-fpm" 2>/dev/null || pgrep -x "php-fpm8" 2>/dev/null || pgrep -x "php-fpm7" 2>/dev/null || pgrep -f "php-fpm" 2>/dev/null)

if [[ -n "$FPM_PIDS" ]]; then
    # Calculate average memory from running processes
    FPM_PROCESS=$(ps -p $(echo "$FPM_PIDS" | head -1) -o comm= 2>/dev/null || echo "php-fpm")
    
    # Sum RSS of all FPM processes
    FPM_COUNT=0
    FPM_SUM=0
    
    for pid in $FPM_PIDS; do
        if [[ -f "/proc/$pid/statm" ]]; then
            RSS_KB=$(awk '{print $2 * 4}' "/proc/$pid/statm" 2>/dev/null) # pages to KB
            if [[ -n "$RSS_KB" ]]; then
                FPM_SUM=$((FPM_SUM + RSS_KB))
                FPM_COUNT=$((FPM_COUNT + 1))
            fi
        fi
    done
    
    if [[ $FPM_COUNT -gt 0 ]]; then
        FPM_MEM=$((FPM_SUM / FPM_COUNT / 1024))  # Convert to MB
        FPM_MEM=$((FPM_MEM > 10 ? FPM_MEM : 50))  # Minimum 50MB
    fi
    
    [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✓${NC} PHP-FPM: $FPM_COUNT processes, avg ${FPM_MEM}MB"
else
    echo -e "${YELLOW}⚠${NC} PHP-FPM not running, using estimate of ${FPM_MEM}MB"
    [[ "$VERBOSE" == true ]] && echo "  (Run PHP-FPM first for accurate measurements)"
fi

# Calculate values
RESERVED_RAM=$((TOTAL_RAM / 4))
AVAILABLE_RAM=$((TOTAL_RAM - RESERVED_RAM))
MAX_CHILDREN=$((AVAILABLE_RAM / FPM_MEM))

# Apply safe boundaries
[[ $MAX_CHILDREN -lt 2 ]] && MAX_CHILDREN=2
[[ $MAX_CHILDREN -gt 1000 ]] && MAX_CHILDREN=1000

START_SERVERS=$((MAX_CHILDREN / 4))
[[ $START_SERVERS -lt 2 ]] && START_SERVERS=2

MIN_SPARE_SERVERS=$((MAX_CHILDREN / 8))
[[ $MIN_SPARE_SERVERS -lt 1 ]] && MIN_SPARE_SERVERS=1

MAX_SPARE_SERVERS=$((MAX_CHILDREN / 2))
[[ $MAX_SPARE_SERVERS -lt 4 ]] && MAX_SPARE_SERVERS=4

# Display results
echo ""
echo -e "${CYAN}=== System Information ===${NC}"
echo -e "Total RAM:              ${GREEN}${TOTAL_RAM}MB${NC}"
echo -e "CPU Cores:              ${GREEN}${CPU_CORES}${NC}"
echo -e "Reserved System RAM:    ${GREEN}${RESERVED_RAM}MB${NC} (25%)"
echo -e "Available for PHP:      ${GREEN}${AVAILABLE_RAM}MB${NC}"
echo -e "Avg FPM Process Memory: ${GREEN}~${FPM_MEM}MB${NC}"

echo ""
echo -e "${CYAN}=== Recommended PHP-FPM Settings ===${NC}"
echo -e "Add these to your ${YELLOW}www.conf${NC} file:"
echo ""
echo "pm = dynamic"
echo "pm.max_children = ${MAX_CHILDREN}"
echo "pm.start_servers = ${START_SERVERS}"
echo "pm.min_spare_servers = ${MIN_SPARE_SERVERS}"
echo "pm.max_spare_servers = ${MAX_SPARE_SERVERS}"
echo ""
echo "pm.max_requests = 500"
echo "pm.process_idle_timeout = 10s"

echo ""
echo -e "${CYAN}=== Explanation ===${NC}"
echo -e "• max_children:         ${MAX_CHILDREN} (based on ${AVAILABLE_RAM}MB available RAM)"
echo -e "• start_servers:        ${START_SERVERS} (25% of max)"
echo -e "• min_spare_servers:    ${MIN_SPARE_SERVERS} (12.5% of max)"
echo -e "• max_spare_servers:    ${MAX_SPARE_SERVERS} (50% of max)"

echo ""
echo -e "${CYAN}=== Done ===${NC}"
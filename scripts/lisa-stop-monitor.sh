#!/bin/bash
# lisa-stop-monitor.sh - Stop the running oversight monitor

# Get script directory, lisa folder, and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# PID file is in lisa folder
MONITOR_PID_FILE="$LISA_DIR/.lisa-monitor.pid"

echo "🛑 Stopping Lisa Monitor..."
echo ""

if [[ ! -f "$MONITOR_PID_FILE" ]]; then
    echo -e "${YELLOW}⚠ Monitor PID file not found${NC}"
    echo "Monitor may not be running, or was started from a different location."
    echo ""
    echo "PID file expected at: $MONITOR_PID_FILE"
    exit 1
fi

MONITOR_PID=$(cat "$MONITOR_PID_FILE")

# Check if process is running
if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Monitor process (PID $MONITOR_PID) is not running${NC}"
    echo "Cleaning up stale PID file..."
    rm -f "$MONITOR_PID_FILE"
    echo -e "${GREEN}✓ Cleaned up${NC}"
    exit 0
fi

# Send TERM signal for graceful shutdown
echo "Sending termination signal to monitor (PID: $MONITOR_PID)..."
kill -TERM "$MONITOR_PID" 2>/dev/null

# Wait up to 5 seconds for graceful shutdown
for i in {1..5}; do
    if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
        echo -e "${GREEN}✓ Monitor stopped gracefully${NC}"
        exit 0
    fi
    sleep 1
    echo "  Waiting for monitor to stop... ($i/5)"
done

# Force kill if still running
if kill -0 "$MONITOR_PID" 2>/dev/null; then
    echo -e "${YELLOW}Monitor didn't stop gracefully, forcing termination...${NC}"
    kill -9 "$MONITOR_PID" 2>/dev/null || true
    sleep 1

    if kill -0 "$MONITOR_PID" 2>/dev/null; then
        echo -e "${RED}✗ Failed to stop monitor${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Monitor force-stopped${NC}"
    fi
fi

echo ""
echo "Monitor terminated successfully."
echo ""

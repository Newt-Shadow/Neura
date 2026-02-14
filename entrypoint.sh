#!/bin/bash
set -e

# ==============================================================================
# COLORS & FORMATTING
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper to try and find the container's IP (Best Effort)
get_ip() {
    ip route get 1.2.3.4 | awk '{print $7}' 2>/dev/null || echo "LOCALHOST"
}

CONTAINER_IP=$(get_ip)

# ==============================================================================
# BANNER
# ==============================================================================
clear
echo -e "${CYAN}"
echo "███╗   ██╗███████╗██╗   ██╗██████╗  █████╗ "
echo "████╗  ██║██╔════╝██║   ██║██╔══██╗██╔══██╗"
echo "██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║"
echo "██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║"
echo "██║ ╚████║███████╗╚██████╔╝██║  ██║██║  ██║"
echo "╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${BLUE}${BOLD}   AI Assistant & Task Manager${NC}"
echo -e "${BLUE}   Build: Stable | Env: Docker${NC}"
echo ""

# ==============================================================================
# WARNINGS SECTION
# ==============================================================================
echo -e "${YELLOW}⚠️  CRITICAL NOTICES:${NC}"
echo "---------------------------------------------------------------------"
echo -e "1. ${BOLD}BETA SOFTWARE:${NC} This app is in active development."
echo -e "2. ${BOLD}WEB LIMITATIONS:${NC}"
echo "   ❌ Local LLM (On-Device AI) is DISABLED."
echo "   ❌ Offline Computer Vision is DISABLED."
echo "   ✅ Uses Cloud API calls strictly."
echo -e "3. ${BOLD}ANDROID APK:${NC}"
echo "   ✅ Full offline capabilities & Local LLM enabled."
echo "---------------------------------------------------------------------"
echo ""

# ==============================================================================
# INTERACTIVE MENU
# ==============================================================================
echo -e "${BOLD}Select launch mode:${NC}"
echo -e "   [${GREEN}1${NC}] 🚀 Launch Server (Web + APK Host)"
echo -e "   [${RED}2${NC}] 🚪 Exit"
echo ""

# Timeout logic: default to 1 after 10 seconds
echo -e -n "Enter choice (Auto-start in 10s): "
read -t 10 choice || choice=1
echo ""

if [[ "$choice" == "2" ]]; then
    echo -e "${RED}Exiting container...${NC}"
    exit 0
fi

# ==============================================================================
# SERVER LAUNCH
# ==============================================================================
clear
echo -e "${GREEN}✅ Initializing Nginx Server...${NC}"
echo ""
echo -e "${BOLD}=====================================================================${NC}"
echo -e "${BOLD}                     ACCESS DASHBOARD                                ${NC}"
echo -e "${BOLD}=====================================================================${NC}"
echo ""
echo -e "${CYAN}🖥️  WEB APP (Chrome):${NC}"
echo -e "   👉 http://localhost:8080"
echo ""
echo -e "${CYAN}📱  ANDROID INSTALLATION:${NC}"
echo -e "   ${BOLD}Option A: Direct Download (From Phone)${NC}"
echo "     1. Ensure phone and PC are on the same Wi-Fi."
echo "     2. Find your PC's IP address (run 'ipconfig' or 'ifconfig' on PC)."
echo "     3. Visit on phone: http://<YOUR_PC_IP>:8080/neura.apk"
echo ""
echo -e "   ${BOLD}Option B: USB Transfer${NC}"
echo "     1. Download to laptop: http://localhost:8080/neura.apk"
echo "     2. Transfer 'neura.apk' to your phone via USB cable."
echo ""
echo -e "${BOLD}=====================================================================${NC}"
echo -e "${BLUE}Starting logs (Press Ctrl+C to stop)...${NC}"
echo ""

# Start Nginx in foreground
exec nginx -g "daemon off;"
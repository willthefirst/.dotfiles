#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Simple logging wrapper for use in Makefile
# Usage: ./scripts/log.sh <level> <message>
# Levels: ok, error, warn, step, info
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

level="$1"
shift
message="$*"

case "$level" in
    ok)    echo -e "  ${GREEN}✓${NC} $message" ;;
    error) echo -e "  ${RED}✗${NC} $message" ;;
    warn)  echo -e "  ${YELLOW}!${NC} $message" ;;
    step)  echo -e "  ${GREEN}→${NC} $message" ;;
    info)  echo -e "  $message" ;;
    *)     echo -e "  $message" ;;
esac

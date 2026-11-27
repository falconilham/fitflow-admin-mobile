#!/bin/bash
# ==============================================================================
# FitFlow Mobile - BLA (Blind LLM Agents) Hardening & Counter-REA Auditor
# Melindungi artefak build mobile (DEX & Native ELF libapp.so) dari dekompilasi AI
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

ACTION="${1:-audit}"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  FitFlow Mobile - Blind LLM Agents (BLA) Hardening Suite       ${NC}"
echo -e "${CYAN}================================================================${NC}"

case "$ACTION" in
  doctor)
    echo -e "${GREEN}>>> Memeriksa kesiapan engine BLA...${NC}"
    npx -y bla-agents@latest doctor
    ;;

  audit)
    echo -e "${BLUE}>>> Menjalankan Counter-REA Security Audit pada artefak build...${NC}"
    DEX_DIR="build/app/intermediates/dex"
    NATIVE_DIR="build/app/intermediates/stripped_native_libs"

    FOUND=0
    if [ -d "$DEX_DIR" ]; then
      echo -e "${YELLOW}• Menemukan direktori DEX Android ($DEX_DIR):${NC}"
      npx -y bla-agents@latest audit "$DEX_DIR" || true
      FOUND=1
    fi

    if [ -d "$NATIVE_DIR" ]; then
      echo -e "${YELLOW}• Menemukan direktori Native ELF ($NATIVE_DIR):${NC}"
      npx -y bla-agents@latest audit "$NATIVE_DIR" || true
      FOUND=1
    fi

    if [ $FOUND -eq 0 ]; then
      echo -e "${YELLOW}Artefak build belum ditemukan di folder 'build/'.${NC}"
      echo "Silakan jalankan 'flutter build apk --release' terlebih dahulu sebelum melakukan audit."
    fi
    ;;

  harden)
    echo -e "${GREEN}>>> Menjalankan Counter-REA Hardening & Verification (Bankrupt Preset)...${NC}"
    DEX_DIR="build/app/intermediates/dex/release/minifyReleaseWithR8"
    NATIVE_ARM64_SO="build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib/arm64-v8a/libapp.so"

    if [ ! -d "$DEX_DIR" ]; then
      DEX_DIR="build/app/intermediates/dex"
    fi

    if [ -d "$DEX_DIR" ]; then
      echo -e "${YELLOW}• Meng-harden DEX Android ($DEX_DIR)...${NC}"
      find "$DEX_DIR" -name ".bla-hardened" -type d -exec rm -rf {} + 2>/dev/null || true
      npx -y bla-agents@latest harden "$DEX_DIR" --intensity bankrupt || true
      if [ -f "$DEX_DIR/.bla-hardened/classes.dex" ] && [ -f "$DEX_DIR/classes.dex" ]; then
        npx -y bla-agents@latest verify "$DEX_DIR/.bla-hardened/classes.dex" "$DEX_DIR/classes.dex" || true
      fi
    fi

    if [ -f "$NATIVE_ARM64_SO" ]; then
      NATIVE_OUT_DIR="$(dirname "$NATIVE_ARM64_SO")"
      echo -e "${YELLOW}• Meng-harden Native Flutter AOT ELF ($NATIVE_ARM64_SO)...${NC}"
      rm -rf "$NATIVE_OUT_DIR/.bla-hardened" 2>/dev/null || true
      npx -y bla-agents@latest harden "$NATIVE_ARM64_SO" --intensity bankrupt || true
      if [ -f "$NATIVE_OUT_DIR/.bla-hardened/libapp.so" ]; then
        npx -y bla-agents@latest verify "$NATIVE_OUT_DIR/.bla-hardened/libapp.so" "$NATIVE_ARM64_SO" || true
      fi
    fi

    echo -e "${GREEN}✓ Hardening & Verifikasi BLA selesai! Artefak tersimpan di .bla-hardened/${NC}"
    ;;

  *)
    echo -e "${RED}Perintah tidak dikenal: $ACTION${NC}"
    echo "Penggunaan: ./scripts/bla-harden.sh [doctor|audit|harden]"
    exit 1
    ;;
esac

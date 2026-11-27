#!/bin/bash
# ==============================================================================
# FitFlow Mobile - BLA (Blind LLM Agents) Hardening, Counter-REA Audit & APK Repack
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

ACTION="${1:-audit}"

resolve_build_tools_dir() {
  local sdk_root="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [ -d "$sdk_root/build-tools" ]; then
    ls -1d "$sdk_root/build-tools"/* 2>/dev/null | sort -V | tail -n 1
  fi
}

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  FitFlow Mobile - Blind LLM Agents (BLA) Hardening Suite       ${NC}"
echo -e "${CYAN}================================================================${NC}"

harden_artifacts() {
  echo -e "${GREEN}>>> Menjalankan Counter-REA Hardening & Verification (Bankrupt Preset)...${NC}"
  local dex_dir="build/app/intermediates/dex/release/minifyReleaseWithR8"
  if [ ! -d "$dex_dir" ]; then
    dex_dir="build/app/intermediates/dex"
  fi

  if [ -d "$dex_dir" ]; then
    echo -e "${YELLOW}• Meng-harden DEX Android ($dex_dir)...${NC}"
    find "$dex_dir" -name ".bla-hardened" -type d -exec rm -rf {} + 2>/dev/null || true
    npx -y bla-agents@latest harden "$dex_dir" --intensity bankrupt || true
    if [ -f "$dex_dir/.bla-hardened/classes.dex" ] && [ -f "$dex_dir/classes.dex" ]; then
      npx -y bla-agents@latest verify "$dex_dir/.bla-hardened/classes.dex" "$dex_dir/classes.dex" || true
    fi
  fi

  local native_root="build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib"
  local abi
  for abi in arm64-v8a armeabi-v7a x86_64; do
    local so_file="$native_root/$abi/libapp.so"
    if [ -f "$so_file" ]; then
      local out_dir
      out_dir="$(dirname "$so_file")"
      echo -e "${YELLOW}• Meng-harden Native Flutter AOT ELF ($abi)...${NC}"
      rm -rf "$out_dir/.bla-hardened" 2>/dev/null || true
      npx -y bla-agents@latest harden "$so_file" --intensity bankrupt || true
      if [ -f "$out_dir/.bla-hardened/libapp.so" ]; then
        npx -y bla-agents@latest verify "$out_dir/.bla-hardened/libapp.so" "$so_file" || true
      fi
    fi
  done

  echo -e "${GREEN}✓ Hardening & Verifikasi BLA selesai! Artefak tersimpan di .bla-hardened/${NC}"
}

repack_apk() {
  local apk_path="$1"
  local mode_flag="${2:-}"

  if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
    echo -e "${RED}Error: APK tidak ditemukan: '$apk_path'${NC}"
    exit 1
  fi

  local abs_apk
  abs_apk="$(cd "$(dirname "$apk_path")" && pwd)/$(basename "$apk_path")"

  local bt_dir
  bt_dir="$(resolve_build_tools_dir)"
  if [ -z "$bt_dir" ] || [ ! -x "$bt_dir/zipalign" ] || [ ! -x "$bt_dir/apksigner" ]; then
    echo -e "${RED}Error: Android SDK zipalign/apksigner tidak ditemukan di ANDROID_HOME/build-tools.${NC}"
    exit 1
  fi

  local dex_hardened="build/app/intermediates/dex/release/minifyReleaseWithR8/.bla-hardened/classes.dex"
  if [ ! -f "$dex_hardened" ]; then
    harden_artifacts
  fi

  if [ ! -f "$dex_hardened" ]; then
    echo -e "${RED}Error: Hardened classes.dex tidak ditemukan di $dex_hardened.${NC}"
    exit 1
  fi

  if [ -x "$bt_dir/dexdump" ]; then
    "$bt_dir/dexdump" -c "$dex_hardened" >/dev/null
    echo -e "${GREEN}✓ Validasi checksum dexdump pada hardened classes.dex lolos.${NC}"
  fi

  local ks_path="${ANDROID_KEYSTORE:-$HOME/.android/debug.keystore}"
  local ks_alias="${ANDROID_KEY_ALIAS:-androiddebugkey}"
  local ks_pass="${ANDROID_KEYSTORE_PASS:-android}"
  local key_pass="${ANDROID_KEY_PASS:-android}"

  if [ ! -f "$ks_path" ]; then
    echo -e "${RED}Error: Keystore tidak ditemukan di $ks_path.${NC}"
    exit 1
  fi

  local work_dir
  work_dir="$(mktemp -d)"
  local inject_dir="$work_dir/inject"
  mkdir -p "$inject_dir"

  local unsigned_apk="$work_dir/unsigned.apk"
  local aligned_apk="$work_dir/aligned.apk"
  local signed_apk="$work_dir/signed.apk"

  cp "$abs_apk" "$unsigned_apk"

  echo -e "${BLUE}>>> Menyuntikkan artefak BLA ke dalam salinan APK tanpa mengekstrak res/...${NC}"
  # Strip old v1 signature files + classes.dex (never extract case-folded AAPT2 res/ entries on macOS APFS)
  zip -q -d "$unsigned_apk" "META-INF/*.SF" "META-INF/*.RSA" "META-INF/*.DSA" "META-INF/*.EC" "META-INF/MANIFEST.MF" "classes.dex" 2>/dev/null || true

  cp "$dex_hardened" "$inject_dir/classes.dex"
  (
    cd "$inject_dir"
    zip -q "$unsigned_apk" classes.dex
  )
  echo -e "${GREEN}✓ Hardened classes.dex disuntikkan ke dalam APK.${NC}"

  if [ "$mode_flag" != "--preserve-libapp" ]; then
    local native_root="build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib"
    local abi
    for abi in arm64-v8a armeabi-v7a x86_64; do
      local hardened_so="$native_root/$abi/.bla-hardened/libapp.so"
      if [ -f "$hardened_so" ] && zipinfo -1 "$unsigned_apk" "lib/$abi/libapp.so" >/dev/null 2>&1; then
        zip -q -d "$unsigned_apk" "lib/$abi/libapp.so"
        mkdir -p "$inject_dir/lib/$abi"
        cp "$hardened_so" "$inject_dir/lib/$abi/libapp.so"
        (
          cd "$inject_dir"
          zip -q -0 "$unsigned_apk" "lib/$abi/libapp.so"
        )
        echo -e "${GREEN}✓ Hardened lib/$abi/libapp.so disuntikkan ke dalam APK (stored).${NC}"
      fi
    done
  else
    echo -e "${YELLOW}• Mode Shorebird (--preserve-libapp): lib/*/libapp.so tetap asli agar OTA patch hash selalu cocok.${NC}"
  fi

  "$bt_dir/zipalign" -P 16 -f 4 "$unsigned_apk" "$aligned_apk"
  "$bt_dir/apksigner" sign \
    --ks "$ks_path" \
    --ks-key-alias "$ks_alias" \
    --ks-pass "pass:$ks_pass" \
    --key-pass "pass:$key_pass" \
    --out "$signed_apk" \
    "$aligned_apk"

  "$bt_dir/apksigner" verify --verbose "$signed_apk" >/dev/null
  cp "$signed_apk" "$abs_apk"
  rm -rf "$work_dir"

  echo -e "${GREEN}✓ APK final berhasil di-repack, zipalign (16KB/4KB), dan di-sign ulang: $apk_path${NC}"
}

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
    harden_artifacts
    ;;

  repack)
    shift
    repack_apk "$@"
    ;;

  *)
    echo -e "${RED}Perintah tidak dikenal: $ACTION${NC}"
    echo "Penggunaan: ./scripts/bla-harden.sh [doctor|audit|harden|repack <apk_path> [--preserve-libapp]]"
    exit 1
    ;;
esac

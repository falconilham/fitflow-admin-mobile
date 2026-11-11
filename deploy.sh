#!/bin/bash

# ==============================================================================
# FitFlow Admin Mobile Deployment Script
# Mendukung Semantic Versioning (SemVer: MAJOR.MINOR.PATCH+BUILD)
# Digunakan untuk deploy OTA patch (Shorebird) atau upload APK ke VPS
# Tanpa perlu GitHub Actions
# ==============================================================================

set -e

VPS_ALIAS="biznetgio"                      # Sesuai config ~/.ssh/config
REMOTE_DOWNLOADS_DIR="~/fitflow-backend-docker/downloads"
APK_TARGET_NAME="fitflow-admin.apk"
PUBSPEC_FILE="pubspec.yaml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Semantic Versioning Helpers
# ------------------------------------------------------------------------------
get_current_version() {
  grep "^version: " "$PUBSPEC_FILE" | head -n 1 | sed 's/version: //g' | tr -d ' '
}

parse_semver() {
  local full_ver="$1"
  local ver_name=$(echo "$full_ver" | cut -d'+' -f1)
  local build_num=$(echo "$full_ver" | cut -d'+' -f2)

  local major=$(echo "$ver_name" | cut -d'.' -f1)
  local minor=$(echo "$ver_name" | cut -d'.' -f2)
  local patch=$(echo "$ver_name" | cut -d'.' -f3)

  local next_build=$((build_num + 1))
  local next_patch="$major.$minor.$((patch + 1))+$next_build"
  local next_minor="$major.$((minor + 1)).0+$next_build"
  local next_major="$((major + 1)).0.0+$next_build"

  echo "$major $minor $patch $build_num $next_patch $next_minor $next_major $next_build"
}

update_pubspec_version() {
  local new_version="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $new_version/" "$PUBSPEC_FILE"
  else
    sed -i "s/^version: .*/version: $new_version/" "$PUBSPEC_FILE"
  fi
  echo -e "${GREEN}✓ Versi di $PUBSPEC_FILE berhasil diperbarui ke:${NC} ${YELLOW}$new_version${NC}"
}

prompt_semver_bump() {
  local current_ver=$(get_current_version)
  read major minor patch build_num next_patch next_minor next_major next_build <<< $(parse_semver "$current_ver")

  echo ""
  echo -e "${CYAN}----------------------------------------------------${NC}"
  echo -e "${CYAN}  FitFlow Admin Mobile - Semantic Versioning (SemVer)${NC}"
  echo -e "${CYAN}----------------------------------------------------${NC}"
  echo -e "Versi saat ini di pubspec.yaml: ${YELLOW}$current_ver${NC} (v$major.$minor.$patch, build $build_num)"
  echo ""
  echo "Pilih Semantic Versioning untuk rilis Admin APK ini:"
  echo -e "  ${YELLOW}1)${NC} Tetap gunakan versi saat ini (${YELLOW}$current_ver${NC})"
  echo -e "  ${YELLOW}2)${NC} ${GREEN}PATCH Bump${NC} (Bugfix / Hotfix kompatibel)      -> ${GREEN}$next_patch${NC}"
  echo -e "  ${YELLOW}3)${NC} ${BLUE}MINOR Bump${NC} (Fitur baru kompatibel ke belakang) -> ${BLUE}$next_minor${NC}"
  echo -e "  ${YELLOW}4)${NC} ${RED}MAJOR Bump${NC} (Perubahan besar / Breaking changes) -> ${RED}$next_major${NC}"
  echo -e "  ${YELLOW}5)${NC} Input manual versi SemVer"
  echo ""

  local BUMP_CHOICE="$1"
  if [ -z "$BUMP_CHOICE" ]; then
    read -p "Pilihan versi [1/2/3/4/5] (default 1): " BUMP_CHOICE
  fi

  local SELECTED_VERSION="$current_ver"
  case "$BUMP_CHOICE" in
    2|patch|--patch)
      SELECTED_VERSION="$next_patch"
      update_pubspec_version "$SELECTED_VERSION"
      ;;
    3|minor|--minor)
      SELECTED_VERSION="$next_minor"
      update_pubspec_version "$SELECTED_VERSION"
      ;;
    4|major|--major)
      SELECTED_VERSION="$next_major"
      update_pubspec_version "$SELECTED_VERSION"
      ;;
    5|manual)
      read -p "Masukkan versi baru (format X.Y.Z+B, misal 1.0.1+2): " MANUAL_VER
      if [ -n "$MANUAL_VER" ]; then
        SELECTED_VERSION="$MANUAL_VER"
        update_pubspec_version "$SELECTED_VERSION"
      fi
      ;;
    1|current|--current|*)
      echo -e "${YELLOW}Menggunakan versi saat ini ($current_ver).${NC}"
      ;;
  esac

  FINAL_VERSION="$SELECTED_VERSION"
  FINAL_VERSION_NAME=$(echo "$FINAL_VERSION" | cut -d'+' -f1)
  FINAL_BUILD_NUM=$(echo "$FINAL_VERSION" | cut -d'+' -f2)
}

# ------------------------------------------------------------------------------
# Header & Menu
# ------------------------------------------------------------------------------
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  FitFlow Admin Mobile Deployment & Release Manager  ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo ""
CURRENT_VER=$(get_current_version)
echo -e "Status Aplikasi Admin: ${YELLOW}$CURRENT_VER${NC}"
echo ""
echo "Pilih metode deployment yang ingin dijalankan:"
echo -e "  ${YELLOW}1)${NC} ${GREEN}Deploy OTA Patch Instan (Shorebird)${NC}"
echo "     • Pembaruan kode langsung terkirim ke seluruh HP Admin/Resepsionis (~300 KB)"
echo "     • Mengikuti rilis SemVer saat ini tanpa perlu download ulang APK"
echo ""
echo -e "  ${YELLOW}2)${NC} ${BLUE}Build Release APK & Upload ke Server VPS (api.fitflow.id)${NC}"
echo "     • Mengelola kenaikan Semantic Versioning (Patch / Minor / Major)"
echo "     • Mengompilasi APK baru dan otomatis upload ke server VPS"
echo "     • Tersedia di: https://api.fitflow.id/downloads/$APK_TARGET_NAME"
echo ""
echo -e "  ${YELLOW}3)${NC} Build Release APK Saja (Lokal)"
echo "     • Hanya kompilasi APK di folder lokal tanpa upload"
echo ""

CHOICE="$1"
if [ -z "$CHOICE" ]; then
  read -p "Masukkan pilihan Anda [1/2/3]: " CHOICE
fi

case "$CHOICE" in
  1|patch)
    echo ""
    echo -e "${GREEN}>>> [1/3] Menyiapkan environment produksi...${NC}"
    cp .env.example .env 2>/dev/null || true

    CURRENT_VER=$(get_current_version)
    echo -e "${GREEN}>>> [2/3] Mempublikasikan Shorebird Android Patch untuk SemVer: v$CURRENT_VER...${NC}"
    shorebird patch android --allow-asset-diffs --release-version="$CURRENT_VER"

    echo ""
    echo -e "${GREEN}>>> [3/3] Selesai!${NC}"
    echo -e "${GREEN}✓ OTA Patch Admin berhasil dipublikasikan untuk base v$CURRENT_VER!${NC}"
    echo "Pengguna akan otomatis mendapatkan pembaruan saat membuka aplikasi."
    ;;

  2|release|vps)
    # Kelola SemVer bump
    prompt_semver_bump "$2"

    echo ""
    echo -e "${BLUE}>>> [1/5] Menyiapkan environment produksi...${NC}"
    cp .env.example .env 2>/dev/null || true

    echo -e "${BLUE}>>> [2/5] Mengompilasi Shorebird Release APK Admin (v$FINAL_VERSION)...${NC}"
    if command -v shorebird &> /dev/null; then
      shorebird release android --artifact=apk --flutter-version=3.41.4
    else
      echo -e "${YELLOW}Shorebird tidak ditemukan, menggunakan 'flutter build apk --release'...${NC}"
      flutter build apk --release
    fi

    # Temukan file APK hasil build
    BUILT_APK=$(find build/app/outputs/flutter-apk -name "*release*.apk" 2>/dev/null | head -n 1)
    if [ -z "$BUILT_APK" ] || [ ! -f "$BUILT_APK" ]; then
      echo -e "${RED}Gagal menemukan file APK hasil kompilasi.${NC}"
      exit 1
    fi

    echo -e "${BLUE}>>> [3/5] Menyiapkan folder downloads di server VPS ($VPS_ALIAS)...${NC}"
    ssh "$VPS_ALIAS" "mkdir -p $REMOTE_DOWNLOADS_DIR"

    echo -e "${BLUE}>>> [4/5] Mengunggah APK Admin ke server VPS...${NC}"
    scp "$BUILT_APK" "$VPS_ALIAS:$REMOTE_DOWNLOADS_DIR/$APK_TARGET_NAME"

    echo -e "${BLUE}>>> [5/5] Pembuatan Git Tag (Opsional)...${NC}"
    TAG_NAME="admin-v$FINAL_VERSION_NAME"
    if git rev-parse --git-dir > /dev/null 2>&1; then
      if ! git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
        git tag -a "$TAG_NAME" -m "Release Admin $TAG_NAME (Build $FINAL_BUILD_NUM)" 2>/dev/null || true
        echo -e "${GREEN}✓ Git tag '$TAG_NAME' berhasil dibuat lokal.${NC}"
        echo "Untuk push tag ke remote: git push origin $TAG_NAME"
      fi
    fi

    echo ""
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}✓ Deployment APK Admin ke Server Sukses (SemVer: v$FINAL_VERSION)!${NC}"
    echo -e "File APK dapat langsung diunduh di:"
    echo -e "${YELLOW}https://api.fitflow.id/downloads/$APK_TARGET_NAME${NC}"
    echo -e "atau via endpoint redirect:"
    echo -e "${YELLOW}https://api.fitflow.id/api/mobile/download/admin${NC}"
    echo -e "${GREEN}====================================================${NC}"
    ;;

  3|build)
    prompt_semver_bump "$2"

    echo ""
    echo -e "${GREEN}>>> Mengompilasi Release APK Admin (v$FINAL_VERSION)...${NC}"
    flutter build apk --release

    BUILT_APK=$(find build/app/outputs/flutter-apk -name "*release*.apk" 2>/dev/null | head -n 1)
    if [ -n "$BUILT_APK" ] && [ -f "$BUILT_APK" ]; then
      cp "$BUILT_APK" "./$APK_TARGET_NAME"
      echo ""
      echo -e "${GREEN}✓ File APK berhasil disimpan di: ./$APK_TARGET_NAME (v$FINAL_VERSION)${NC}"
    fi
    ;;

  *)
    echo -e "${RED}Pilihan tidak valid. Silakan jalankan: ./deploy.sh [1|2|3]${NC}"
    exit 1
    ;;
esac

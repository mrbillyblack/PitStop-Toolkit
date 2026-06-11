#!/bin/bash
# ==============================================================
# Docker Engine Installation Script for Ubuntu 24.04 (Noble)
# Based on: https://docs.docker.com/engine/install/ubuntu/
# ==============================================================

set -e  # Exit immediately on error

# ── Colours ───────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Root check ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Please run as root or with sudo: sudo bash $0"
fi

# ── OS check ──────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  error "Cannot detect OS. /etc/os-release not found."
fi

if [ "$ID" != "ubuntu" ]; then
  error "This script is intended for Ubuntu only. Detected: $ID"
fi

info "Detected OS: $PRETTY_NAME"

# ── Step 1: Remove conflicting packages ───────────────────────
info "Removing any conflicting/unofficial Docker packages..."

CONFLICTING_PKGS=(
  docker.io
  docker-compose
  docker-compose-v2
  docker-doc
  podman-docker
  containerd
  runc
)

for pkg in "${CONFLICTING_PKGS[@]}"; do
  if dpkg -l "$pkg" &>/dev/null; then
    info "  Removing $pkg..."
    apt-get remove -y "$pkg"
  fi
done

# ── Step 2: Install prerequisites ─────────────────────────────
info "Installing prerequisites (ca-certificates, curl)..."
apt-get update -y
apt-get install -y ca-certificates curl

# ── Step 3: Add Docker's official GPG key ─────────────────────
info "Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# ── Step 4: Add Docker apt repository ─────────────────────────
info "Adding Docker apt repository..."
tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update -y

# ── Step 5: Install Docker Engine ─────────────────────────────
info "Installing Docker Engine, CLI, and plugins..."
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# ── Step 6: Enable and start Docker ───────────────────────────
info "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

# ── Step 7: Optional — add current user to docker group ───────
# Allows running docker without sudo for the invoking user.
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
  info "Adding '$SUDO_USER' to the 'docker' group..."
  usermod -aG docker "$SUDO_USER"
  # Activate the new group in the current shell without requiring a logout
  info "Activating docker group for current session..."
  su - "$SUDO_USER" -c "newgrp docker"
fi

# ── Step 8: Verify installation ───────────────────────────────
info "Verifying installation with hello-world container..."
docker run --rm hello-world

echo ""
echo -e "${GREEN}✔ Docker Engine installed successfully!${NC}"
docker --version
docker compose version

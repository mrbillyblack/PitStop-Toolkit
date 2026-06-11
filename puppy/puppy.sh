#!/usr/bin/env bash
# puppy.sh — install and configure Mutt with a Gmail account
# Usage:
#   ./puppy.sh               # fresh install + configure
#   ./puppy.sh --reconfigure # reconfigure only (skip install)

set -euo pipefail

MUTT_DIR="$HOME/.mutt"
MUTTRC="$MUTT_DIR/muttrc"
CACHE_DIR="$MUTT_DIR/cache"

# ── helpers ──────────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo "╔══════════════════════════════╗"
  echo "║          puppy.sh            ║"
  echo "╚══════════════════════════════╝"
  echo ""
}

info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()     { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

prompt() {
  # prompt <var_name> <display_label> [default]
  local var="$1" label="$2" default="${3:-}"
  local value=""
  if [[ -n "$default" ]]; then
    read -rp "  $label [$default]: " value
    value="${value:-$default}"
  else
    while [[ -z "$value" ]]; do
      read -rp "  $label: " value
      [[ -z "$value" ]] && warn "This field is required."
    done
  fi
  printf -v "$var" '%s' "$value"
}

prompt_password() {
  local var="$1" label="$2"
  local value=""
  while [[ -z "$value" ]]; do
    read -rsp "  $label: " value
    echo ""
    [[ -z "$value" ]] && warn "This field is required."
  done
  printf -v "$var" '%s' "$value"
}

# ── install ───────────────────────────────────────────────────────────────────

install_mutt() {
  info "Checking for Mutt..."
  if command -v mutt &>/dev/null; then
    success "Mutt is already installed ($(mutt -v | head -1))."
    return
  fi

  info "Installing Mutt via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y mutt
  success "Mutt installed."
}

# ── configure ─────────────────────────────────────────────────────────────────

gather_input() {
  echo ""
  echo "  Enter your Gmail details"
  echo "  ─────────────────────────────────────────"
  prompt     REAL_NAME    "Full name (e.g. Jane Smith)"
  prompt     USER_EMAIL   "Gmail address"
  echo ""
  echo "  To get your Gmail App Password:"
  echo "    1. Go to: https://myaccount.google.com/security"
  echo "    2. Under 'How you sign in to Google', open '2-Step Verification'"
  echo "    3. Scroll to the bottom and click 'App passwords'"
  echo "    4. Select app: Mail — Select device: Other — name it 'Mutt'"
  echo "    5. Copy the 16-character password Google gives you"
  echo ""
  prompt_password APP_PASS "App password (input hidden)"
  echo ""

  # Basic email validation
  [[ "$USER_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]] \
    || die "'$USER_EMAIL' doesn't look like a valid email address."
}

write_muttrc() {
  info "Creating $MUTT_DIR ..."
  mkdir -p "$CACHE_DIR"

  info "Writing $MUTTRC ..."
  cat > "$MUTTRC" << EOF
# ── identity ──────────────────────────────────────────────────────────────────
set realname  = "${REAL_NAME}"
set from      = "${USER_EMAIL}"

# ── IMAP (incoming) ───────────────────────────────────────────────────────────
set imap_user   = "${USER_EMAIL}"
set imap_pass   = "${APP_PASS}"
set folder      = "imaps://imap.gmail.com:993"
set spoolfile   = "+INBOX"
set postponed   = "+[Gmail]/Drafts"
set trash       = "+[Gmail]/Trash"

# ── SMTP (outgoing) ───────────────────────────────────────────────────────────
set smtp_url  = "smtps://${USER_EMAIL}@smtp.gmail.com:465"
set smtp_pass = "${APP_PASS}"

# ── TLS ───────────────────────────────────────────────────────────────────────
set ssl_force_tls  = yes
set ssl_starttls   = yes

# ── cache ─────────────────────────────────────────────────────────────────────
set header_cache    = ~/.mutt/cache/headers
set message_cachedir = ~/.mutt/cache/bodies
set certificate_file = ~/.mutt/certificates

# ── general ───────────────────────────────────────────────────────────────────
set move         = no       # don't move read mail out of INBOX
set imap_keepalive = 300
set mail_check   = 60

# ── sidebar ───────────────────────────────────────────────────────────────────
set sidebar_visible = yes
set sidebar_width   = 25
EOF

  chmod 600 "$MUTTRC"
  success "muttrc written and permissions set (600)."
}

# ── reconfigure guard ─────────────────────────────────────────────────────────

check_reconfigure() {
  # If not --reconfigure and a config already exists, warn and offer to bail
  if [[ -f "$MUTTRC" ]]; then
    warn "An existing muttrc was found at $MUTTRC"
    read -rp "  Overwrite it? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || { info "Aborted. Run ./puppy.sh --reconfigure to update later."; exit 0; }
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

print_banner

RECONFIGURE=false
[[ "${1:-}" == "--reconfigure" ]] && RECONFIGURE=true

if $RECONFIGURE; then
  info "Reconfigure mode — skipping install."
  [[ -f "$MUTTRC" ]] && info "Current config: $MUTTRC"
else
  install_mutt
  check_reconfigure
fi

gather_input
write_muttrc

echo ""
success "All done! Run 'mutt' to open your inbox."
echo "  Tip: on first launch accept Gmail's SSL cert by pressing 'a'."
echo ""

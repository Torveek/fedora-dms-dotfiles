#!/usr/bin/env bash
# install_dms.sh - Standalone installer for Dank Material Shell & Niri on Fedora
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootstrap 'gum' if missing on a fresh system
bootstrap_gum() {
    if ! command -v gum >/dev/null 2>&1; then
        echo -e "\033[1m\033[34m[INFO]\033[0m 'gum' is not installed. Attempting to bootstrap 'gum' via DNF..."
        if [ "${DRY_RUN:-false}" = "true" ]; then
            echo -e "\033[1m\033[35m[DRY-RUN]\033[0m Would execute: sudo dnf install -y gum"
        else
            if command -v sudo >/dev/null 2>&1; then
                sudo dnf install -y gum >/dev/null 2>&1 || true
            fi
        fi
    fi
}

# Parse early dry-run flag for bootstrap
for arg in "$@"; do
    if [ "$arg" = "-n" ] || [ "$arg" = "--dry-run" ]; then
        DRY_RUN=true
        export DRY_RUN
    fi
done

bootstrap_gum

# Source config, UI, and DMS phase module
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/dms_phase.sh"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Standalone installer for Dank Material Shell (DMS) and Niri on Fedora.
Executes the official DankLinux automatic installation (curl -fsSL https://install.danklinux.com | sh),
configures and enables dms-greeter for greetd, and enables dms.service.

Options:
  -h, --help            Show this help message and exit
  -n, --dry-run         Simulate installation without modifying files or system packages
  -y, --yes             Automatic yes to prompts; run non-interactively
  --force, --reinstall  Force re-running installer even if DMS packages are already present
  --manual              Use manual COPR repositories and DNF package installation
  --auto                Use official automatic DankLinux installer (default)
  --no-greeter          Skip configuring dms-greeter and greetd service
  --compositor <name>   Compositor to install (default: niri)
  --term <name>         Terminal emulator to install (default: alacritty)

Examples:
  ./install_dms.sh --dry-run      # Preview installation commands safely
  ./install_dms.sh                # Interactive installation
  ./install_dms.sh -y             # Unattended installation
  ./install_dms.sh --force        # Force update / reinstall via official installer
EOF
}

# Defaults
DRY_RUN=false
ASSUME_YES=false
FORCE_INSTALL=false
INSTALL_METHOD="${DMS_INSTALL_METHOD:-auto}"
SETUP_GREETER=true
COMPOSITOR="${DMS_INSTALLER_COMPOSITOR:-niri}"
TERM_EMU="${DMS_INSTALLER_TERM:-alacritty}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        --force|--reinstall)
            FORCE_INSTALL=true
            shift
            ;;
        --manual)
            INSTALL_METHOD="manual"
            shift
            ;;
        --auto)
            INSTALL_METHOD="auto"
            shift
            ;;
        --no-greeter)
            SETUP_GREETER=false
            shift
            ;;
        --compositor)
            COMPOSITOR="$2"
            shift 2
            ;;
        --term)
            TERM_EMU="$2"
            shift 2
            ;;
        *)
            ui_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

export DRY_RUN ASSUME_YES
export FORCE_DMS_INSTALL="$FORCE_INSTALL"
export DMS_INSTALL_METHOD="$INSTALL_METHOD"
export DMS_SETUP_GREETER="$SETUP_GREETER"
export DMS_INSTALLER_COMPOSITOR="$COMPOSITOR"
export DMS_INSTALLER_TERM="$TERM_EMU"

if [ "$DRY_RUN" = "true" ]; then
    ui_header "DMS Dank Linux Installation [DRY-RUN]" "Simulating installation without system modification"
else
    ui_header "DMS Dank Linux Installation" "Installing DankMaterialShell, Niri & dms-greeter"
    if [ "$ASSUME_YES" = "false" ]; then
        if ! ui_confirm "Do you want to proceed with installing DankMaterialShell?" true; then
            ui_info "Installation aborted by user."
            exit 0
        fi
    fi
fi

START_TIME=$(date +%s)

dms_install_standalone

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

ui_header "Installation Finished in ${DURATION}s" "DankMaterialShell environment setup is complete!"

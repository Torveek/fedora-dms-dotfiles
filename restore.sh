#!/usr/bin/env bash
# restore.sh - Entrypoint for restoring Fedora DMS, packages, configs, and services
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

# Source config and modules
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/dms_phase.sh"
source "${SCRIPT_DIR}/lib/repos.sh"
source "${SCRIPT_DIR}/lib/packages.sh"
source "${SCRIPT_DIR}/lib/flatpaks.sh"
source "${SCRIPT_DIR}/lib/dotfiles.sh"
source "${SCRIPT_DIR}/lib/dconf.sh"
source "${SCRIPT_DIR}/lib/services.sh"

trap ui_flush_input EXIT

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Restores Dank Material Shell, Niri, DNF packages, COPR repos, Flatpaks,
dconf desktop settings, systemd user services, and dotfiles.

Options:
  -h, --help            Show this help message and exit
  -n, --dry-run         Simulate restore actions without modifying any files or packages
  -y, --yes             Automatic yes to prompts; run non-interactively
  --all                 Full restoration (DMS first, then repos, pkgs, flatpaks, dotfiles, dconf, services)
  --dms-auto            Use official DankLinux automatic installer for DMS (curl -fsSL https://install.danklinux.com | sh) [default]
  --dms-manual          Use manual COPR repositories and DNF package installation for DMS
  --force-dms           Force running DMS installer even if core packages are already installed
  --skip-unavailable    Skip unavailable packages during DNF install (default: enabled)
  --no-skip-unavailable Do not skip unavailable packages (fail if any package is missing)
  --dms-only            Restore ONLY Dank Material Shell & Niri priority setup
  --repos               Restore secondary COPRs and RPM repos
  --packages            Restore DNF user-installed packages
  --flatpaks            Restore Flatpak remotes and applications
  --dotfiles            Restore Zsh dotfiles, Oh My Zsh plugins, and fonts (with safety backups)
  --dconf               Restore dconf desktop settings (themes, fonts, dark mode)
  --services            Restore systemd user services

Examples:
  ./restore.sh --dry-run        # Preview full restore process safely
  ./restore.sh --all            # Complete system restoration (official DMS installer first)
  ./restore.sh --dms-only       # Quickly set up just DMS and Niri via official installer
  ./restore.sh --dms-manual     # Restore using manual COPRs and DNF packages
EOF
}

# Parse command line flags
DO_ALL=false
DO_DMS=false
DO_REPOS=false
DO_PACKAGES=false
DO_FLATPAKS=false
DO_DOTFILES=false
DO_DCONF=false
DO_SERVICES=false
DRY_RUN=false
ASSUME_YES=false
SKIP_UNAVAILABLE=true
FORCE_DMS_INSTALL=false
DMS_INSTALL_METHOD="${DMS_INSTALL_METHOD:-auto}"

ANY_MODULE_SPECIFIED=false

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
        --all)
            DO_ALL=true
            shift
            ;;
        --dms-auto)
            DMS_INSTALL_METHOD="auto"
            shift
            ;;
        --dms-manual)
            DMS_INSTALL_METHOD="manual"
            shift
            ;;
        --force-dms)
            FORCE_DMS_INSTALL=true
            shift
            ;;
        --no-greeter)
            DMS_SETUP_GREETER=false
            shift
            ;;
        --skip-unavailable)
            SKIP_UNAVAILABLE=true
            shift
            ;;
        --no-skip-unavailable)
            SKIP_UNAVAILABLE=false
            shift
            ;;
        --dms-only)
            DO_DMS=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --repos)
            DO_REPOS=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --packages)
            DO_PACKAGES=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --flatpaks)
            DO_FLATPAKS=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --dotfiles)
            DO_DOTFILES=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --dconf)
            DO_DCONF=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        --services)
            DO_SERVICES=true
            ANY_MODULE_SPECIFIED=true
            shift
            ;;
        *)
            ui_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

export DRY_RUN ASSUME_YES SKIP_UNAVAILABLE DMS_INSTALL_METHOD FORCE_DMS_INSTALL DMS_SETUP_GREETER

# If no specific module flag was passed, handle default or interactive choice
if [ "$ANY_MODULE_SPECIFIED" = "false" ] && [ "$DO_ALL" = "false" ]; then
    if has_gum && [ "$DRY_RUN" = "false" ] && [ "$ASSUME_YES" = "false" ]; then
        CHOICE=$(gum choose "Full Restore (All Phases, DMS First)" "DMS & Niri Only" "Selective Restore" "Dry-Run Full Restore" "Cancel")
        case "$CHOICE" in
            "Full Restore (All Phases, DMS First)")
                DO_ALL=true
                ;;
            "DMS & Niri Only")
                DO_DMS=true
                ;;
            "Dry-Run Full Restore")
                DO_ALL=true
                DRY_RUN=true
                export DRY_RUN
                ;;
            "Selective Restore")
                SELECTIONS=$(gum choose --no-limit "DMS & Niri" "Repositories" "DNF Packages" "Flatpaks" "Dotfiles & Fonts" "Desktop dconf" "User Services")
                [[ "$SELECTIONS" =~ "DMS & Niri" ]] && DO_DMS=true
                [[ "$SELECTIONS" =~ "Repositories" ]] && DO_REPOS=true
                [[ "$SELECTIONS" =~ "DNF Packages" ]] && DO_PACKAGES=true
                [[ "$SELECTIONS" =~ "Flatpaks" ]] && DO_FLATPAKS=true
                [[ "$SELECTIONS" =~ "Dotfiles & Fonts" ]] && DO_DOTFILES=true
                [[ "$SELECTIONS" =~ "Desktop dconf" ]] && DO_DCONF=true
                [[ "$SELECTIONS" =~ "User Services" ]] && DO_SERVICES=true
                ;;
            *)
                ui_info "Restore cancelled."
                exit 0
                ;;
        esac
    else
        DO_ALL=true
    fi
fi

if [ "$DO_ALL" = "true" ]; then
    DO_DMS=true
    DO_REPOS=true
    DO_PACKAGES=true
    DO_FLATPAKS=true
    DO_DOTFILES=true
    DO_DCONF=true
    DO_SERVICES=true
fi

# Banner
if [ "$DRY_RUN" = "true" ]; then
    ui_header "Fedora DMS Restore [DRY-RUN]" "Simulating restoration flow without modifying system"
else
    ui_header "Fedora DMS Restore" "Provisioning environment (DankMaterialShell prioritized)"
    if ! ui_confirm "Do you want to proceed with the restoration?" true; then
        ui_info "Restoration aborted by user."
        exit 0
    fi
fi

START_TIME=$(date +%s)

# Execution Flow:
# Phase 1: DMS Priority Phase (Compositor, shell, widgets, keybindings, COPRs)
if [ "$DO_DMS" = "true" ]; then
    restore_dms_phase
    export SKIP_DMS_IN_DOTFILES=true
fi

# Phase 2: Secondary Repositories (RPM Fusion, custom repos, secondary COPRs)
if [ "$DO_REPOS" = "true" ]; then
    restore_repos
fi

# Phase 3: DNF User Packages
if [ "$DO_PACKAGES" = "true" ]; then
    restore_packages
fi

# Phase 4: Flatpaks
if [ "$DO_FLATPAKS" = "true" ]; then
    restore_flatpaks
fi

# Phase 5: Dotfiles & Fonts (with safety backups)
if [ "$DO_DOTFILES" = "true" ]; then
    restore_dotfiles
fi

# Phase 6: Desktop dconf settings
if [ "$DO_DCONF" = "true" ]; then
    restore_dconf
fi

# Phase 7: Systemd User Services
if [ "$DO_SERVICES" = "true" ]; then
    restore_services
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Collect all uninstalled packages from DMS core and user packages
ALL_NOT_INSTALLED=()
if [ -n "${NOT_INSTALLED_DMS_PACKAGES[*]:-}" ]; then
    ALL_NOT_INSTALLED+=("${NOT_INSTALLED_DMS_PACKAGES[@]}")
fi
if [ -n "${NOT_INSTALLED_PACKAGES[*]:-}" ]; then
    ALL_NOT_INSTALLED+=("${NOT_INSTALLED_PACKAGES[@]}")
fi

if [ "$DRY_RUN" = "true" ]; then
    ui_header "Dry-Run Completed in ${DURATION}s" "Restore simulation finished without modifying any files or packages"
elif [ "${#ALL_NOT_INSTALLED[@]}" -gt 0 ]; then
    ui_header "Restore Completed with Warnings in ${DURATION}s" "Restoration finished, but some packages were not installed"
    
    echo ""
    ui_warn "The following ${#ALL_NOT_INSTALLED[@]} package(s) were NOT installed (unavailable in repos or failed):"
    for pkg in "${ALL_NOT_INSTALLED[@]}"; do
        ui_list_item "$pkg"
    done
    echo ""
    ui_info "Note: These packages may require custom COPRs, direct RPM downloads, or third-party repositories (e.g. firefoxpwa)."
else
    ui_header "Restore Completed in ${DURATION}s" "All selected components have been successfully restored!"
fi

if [ "$DRY_RUN" = "false" ]; then
    ui_info "Safety backups (if any) are located in: ${RESTORE_BACKUP_BASE}/"
    ui_info "A system restart or logout may be recommended to reload all compositor services."
fi

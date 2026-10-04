#!/usr/bin/env bash
# backup.sh - Entrypoint for backing up Fedora DMS, packages, configs, and services
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Backs up Dank Material Shell, Niri, DNF packages, COPR repos, Flatpaks,
dconf desktop settings, systemd user services, and dotfiles into the repository.

Options:
  -h, --help        Show this help message and exit
  -n, --dry-run     Simulate backup actions without modifying any files
  -y, --yes         Automatic yes to prompts; run non-interactively
  --all             Perform a full backup of all components (default if no flags)
  --dms             Back up DMS & Niri configs, COPRs, and core packages
  --repos           Back up COPR and third-party RPM repository lists
  --packages        Back up DNF user-installed packages and VSCodium extensions
  --flatpaks        Back up Flatpak remotes and installed applications
  --dotfiles        Back up tracked ~/.config, home dotfiles, and fonts
  --dconf           Back up dconf desktop settings (themes, fonts, dark mode)
  --services        Back up user systemd services

Examples:
  ./backup.sh                   # Interactive or full backup
  ./backup.sh --dry-run         # Dry-run preview of full backup
  ./backup.sh --dms --dotfiles  # Back up only DMS and dotfiles
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
        --dms)
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

export DRY_RUN ASSUME_YES

# If no specific module flag was passed, handle default or interactive choice
if [ "$ANY_MODULE_SPECIFIED" = "false" ] && [ "$DO_ALL" = "false" ]; then
    if has_gum && [ "$DRY_RUN" = "false" ] && [ "$ASSUME_YES" = "false" ]; then
        CHOICE=$(gum choose "Full Backup (All Components)" "Selective Backup" "Dry-Run Full Backup" "Cancel")
        case "$CHOICE" in
            "Full Backup (All Components)")
                DO_ALL=true
                ;;
            "Dry-Run Full Backup")
                DO_ALL=true
                DRY_RUN=true
                export DRY_RUN
                ;;
            "Selective Backup")
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
                ui_info "Backup cancelled."
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
    ui_header "Fedora DMS Backup [DRY-RUN]" "Simulating backup process without modifying files"
else
    ui_header "Fedora DMS Backup" "Exporting system state, packages, and configurations"
fi

START_TIME=$(date +%s)

# Execute requested backups
[ "$DO_DMS" = "true" ] && backup_dms_phase
[ "$DO_REPOS" = "true" ] && backup_repos
[ "$DO_PACKAGES" = "true" ] && backup_packages
[ "$DO_FLATPAKS" = "true" ] && backup_flatpaks
[ "$DO_DOTFILES" = "true" ] && backup_dotfiles
[ "$DO_DCONF" = "true" ] && backup_dconf
[ "$DO_SERVICES" = "true" ] && backup_services

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

ui_header "Backup Completed in ${DURATION}s" "Repository is ready for review and git commit"

if [ "$DRY_RUN" = "false" ]; then
    ui_info "Run 'git status' to inspect backed up files."
fi

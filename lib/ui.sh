#!/usr/bin/env bash
# lib/ui.sh - Terminal UI wrappers using Charm's 'gum' with clean ANSI fallback

# Colors for fallback ANSI
ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_DIM="\033[2m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"
ANSI_BLUE="\033[34m"
ANSI_MAGENTA="\033[35m"
ANSI_CYAN="\033[36m"
ANSI_GRAY="\033[90m"

has_gum() {
    command -v gum >/dev/null 2>&1 && [ -t 1 ]
}

ui_header() {
    local text="$1"
    local subtitle="${2:-}"
    if has_gum; then
        if [ -n "$subtitle" ]; then
            gum style \
                --border normal \
                --border-foreground 212 \
                --padding "1 3" \
                --margin "1 0" \
                --align center \
                "$(gum style --bold --foreground 212 "$text")" \
                "$(gum style --foreground 245 "$subtitle")"
        else
            gum style \
                --border normal \
                --border-foreground 212 \
                --padding "1 3" \
                --margin "1 0" \
                --align center \
                "$(gum style --bold --foreground 212 "$text")"
        fi
    else
        echo -e "\n${ANSI_BOLD}${ANSI_MAGENTA}================================================================${ANSI_RESET}"
        echo -e "${ANSI_BOLD}${ANSI_CYAN}  $text${ANSI_RESET}"
        if [ -n "$subtitle" ]; then
            echo -e "${ANSI_DIM}  $subtitle${ANSI_RESET}"
        fi
        echo -e "${ANSI_BOLD}${ANSI_MAGENTA}================================================================${ANSI_RESET}\n"
    fi
}

ui_step() {
    local step_title="$1"
    if has_gum; then
        gum style \
            --foreground 39 \
            --bold \
            --margin "1 0 0 0" \
            "➜ $step_title"
    else
        echo -e "\n${ANSI_BOLD}${ANSI_BLUE}➜ $step_title${ANSI_RESET}"
    fi
}

ui_info() {
    local msg="$1"
    if has_gum; then
        echo "$(gum style --foreground 39 --bold "[INFO]") $msg"
    else
        echo -e "${ANSI_BOLD}${ANSI_BLUE}[INFO]${ANSI_RESET} $msg"
    fi
}

ui_success() {
    local msg="$1"
    if has_gum; then
        echo "$(gum style --foreground 48 --bold "[✓]") $msg"
    else
        echo -e "${ANSI_BOLD}${ANSI_GREEN}[✓]${ANSI_RESET} $msg"
    fi
}

ui_warn() {
    local msg="$1"
    if has_gum; then
        echo "$(gum style --foreground 220 --bold "[WARN]") $msg"
    else
        echo -e "${ANSI_BOLD}${ANSI_YELLOW}[WARN]${ANSI_RESET} $msg"
    fi
}

ui_error() {
    local msg="$1"
    if has_gum; then
        echo "$(gum style --foreground 196 --bold "[ERROR]") $msg" >&2
    else
        echo -e "${ANSI_BOLD}${ANSI_RED}[ERROR]${ANSI_RESET} $msg" >&2
    fi
}

ui_dryrun() {
    local msg="$1"
    if has_gum; then
        echo "$(gum style --foreground 201 --bold "[DRY-RUN]") $msg"
    else
        echo -e "${ANSI_BOLD}${ANSI_MAGENTA}[DRY-RUN]${ANSI_RESET} $msg"
    fi
}

ui_spin() {
    local title="$1"
    shift
    local cmd=("$@")

    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would execute: ${cmd[*]}"
        return 0
    fi

    if has_gum; then
        gum spin --spinner dot --title "$title" -- "${cmd[@]}"
    else
        echo -e "${ANSI_DIM}⏳ $title...${ANSI_RESET}"
        "${cmd[@]}"
    fi
}

ui_confirm() {
    local prompt="$1"
    local default_yes="${2:-true}"

    if [ "${DRY_RUN:-false}" = "true" ] || [ "${ASSUME_YES:-false}" = "true" ]; then
        return 0
    fi

    if [ ! -t 0 ]; then
        # Non-interactive stdin, proceed if default_yes
        [ "$default_yes" = "true" ] && return 0 || return 1
    fi

    if has_gum; then
        if [ "$default_yes" = "true" ]; then
            gum confirm --default=true "$prompt"
        else
            gum confirm --default=false "$prompt"
        fi
    else
        local choice
        if [ "$default_yes" = "true" ]; then
            read -r -p "$prompt [Y/n] " choice
            choice="${choice:-y}"
            [[ "$choice" =~ ^[Yy]$ ]]
        else
            read -r -p "$prompt [y/N] " choice
            choice="${choice:-n}"
            [[ "$choice" =~ ^[Yy]$ ]]
        fi
    fi
}

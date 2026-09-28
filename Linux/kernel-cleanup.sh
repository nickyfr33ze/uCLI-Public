#!/usr/bin/env bash
# =============================================================================
# kernel-cleanup.sh
# Interactive kernel image manager for Debian-based Linux distros
# Supports: Ubuntu, Debian, Kali Linux, Raspberry Pi (Ubuntu/Debian)
#
# Usage:
#   ./kernel-cleanup.sh            # Interactive mode
#   ./kernel-cleanup.sh --dry-run  # Preview only, no changes
#   ./kernel-cleanup.sh --yes      # Auto-confirm all safe removals
# =============================================================================

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Flags ─────────────────────────────────────────────────────────────────────
DRY_RUN=false
AUTO_YES=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "  --dry-run   Show what would be removed without doing it"
    echo "  --yes       Auto-confirm all safe removals (use with caution)"
    echo "  -h, --help  Show this help"
    exit 0
}

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --yes)     AUTO_YES=true ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $arg"; usage ;;
    esac
done

# ── Root / sudo check ─────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
        echo -e "${RED}[!] Not root and sudo not found. Re-run as root.${RESET}"
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
detect_distro() {
    [[ -f /etc/os-release ]] && source /etc/os-release && echo "${PRETTY_NAME:-Unknown}" || echo "Unknown"
}

# Convert dpkg Installed-Size (KB) to human-readable
human_size() {
    local kb="$1"
    if [[ "$kb" =~ ^[0-9]+$ ]]; then
        if (( kb >= 1024 )); then
            awk "BEGIN { printf \"%.1f MB\", $kb/1024 }"
        else
            echo "${kb} KB"
        fi
    else
        echo "unknown"
    fi
}

# All installed versioned kernel image packages, sorted by version
get_versioned_kernels() {
    dpkg --list \
        | awk '/^ii/ && /linux-image-[0-9]/ { print $2 }' \
        | sort -V
}

# All installed packages whose name contains a given version string
get_related_packages() {
    local ver="$1"
    dpkg --list \
        | awk -v ver="$ver" '/^ii/ && $2 ~ ver { print $2 }' \
        | grep -v "^linux-image-${ver}$" \
        || true
}

# ── Raspberry Pi OS detection ─────────────────────────────────────────────────
is_rpi_os() {
    dpkg --list raspberrypi-kernel &>/dev/null 2>&1 && return 0 || return 1
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║       Kernel Cleanup — Debian / Ubuntu / Kali / RPi          ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}Hostname :${RESET} $(hostname)"
    echo -e "  ${BOLD}Distro   :${RESET} $(detect_distro)"
    echo -e "  ${BOLD}Running  :${RESET} ${GREEN}$(uname -r)${RESET}"
    $DRY_RUN && echo -e "  ${YELLOW}[DRY RUN — no changes will be made]${RESET}"
    echo ""

    # ── Raspberry Pi OS special case ──────────────────────────────────────────
    if is_rpi_os; then
        echo -e "${YELLOW}[!] Detected Raspberry Pi OS kernel management.${RESET}"
        echo -e "    Kernels are managed as a single ${BOLD}raspberrypi-kernel${RESET} package."
        echo -e "    There are no versioned images to clean up here."
        echo -e "    Run ${BOLD}sudo apt-get upgrade${RESET} to update the kernel."
        echo ""
        exit 0
    fi

    RUNNING=$(uname -r)

    mapfile -t KERNELS < <(get_versioned_kernels)

    if [[ ${#KERNELS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No versioned kernel packages found. Nothing to do.${RESET}"
        exit 0
    fi

    # Newest = last in version-sorted list
    NEWEST="${KERNELS[-1]}"
    NEWEST_VER="${NEWEST#linux-image-}"

    # ── Display installed kernels ─────────────────────────────────────────────
    echo -e "${DIM}──────────────────────────────────────────────────────────────${RESET}"
    echo -e "\n${BOLD}Installed Kernel Images:${RESET}\n"

    REMOVABLE=()

    for pkg in "${KERNELS[@]}"; do
        ver="${pkg#linux-image-}"
        size=$(dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null || echo "?")

        # Related packages (headers, modules, etc.)
        mapfile -t related < <(get_related_packages "$ver")
        related_str="${related[*]:-none}"

        # Status logic
        if [[ "$ver" == "$RUNNING" && "$pkg" == "$NEWEST" ]]; then
            tag="${GREEN}[RUNNING + NEWEST — PROTECTED]${RESET}"
            protected=true
        elif [[ "$ver" == "$RUNNING" ]]; then
            tag="${GREEN}[RUNNING — PROTECTED]${RESET}"
            protected=true
        elif [[ "$pkg" == "$NEWEST" ]]; then
            tag="${YELLOW}[NEWEST — PROTECTED]${RESET}"
            protected=true
        else
            tag="${RED}[REMOVABLE]${RESET}"
            protected=false
        fi

        echo -e "  ${BOLD}${pkg}${RESET}"
        echo -e "    Status  : $(echo -e "$tag")"
        echo -e "    Size    : ${DIM}$(human_size "$size")${RESET}"
        if [[ "$related_str" != "none" && -n "$related_str" ]]; then
            echo -e "    Related : ${DIM}${related_str}${RESET}"
        fi
        echo ""

        $protected || REMOVABLE+=("$pkg")
    done

    # ── Summary ───────────────────────────────────────────────────────────────
    echo -e "${DIM}──────────────────────────────────────────────────────────────${RESET}"
    echo -e "\n${BOLD}Summary:${RESET}"
    echo -e "  Total installed : ${BOLD}${#KERNELS[@]}${RESET}"
    echo -e "  Protected       : ${GREEN}$(( ${#KERNELS[@]} - ${#REMOVABLE[@]} ))${RESET}  (running and/or newest)"
    echo -e "  Removable       : ${RED}${#REMOVABLE[@]}${RESET}"

    if [[ ${#REMOVABLE[@]} -eq 0 ]]; then
        echo -e "\n${GREEN}Nothing to remove — your kernel list is already clean.${RESET}\n"
        exit 0
    fi

    # ── Action menu ───────────────────────────────────────────────────────────
    echo ""
    echo -e "${DIM}──────────────────────────────────────────────────────────────${RESET}"
    echo -e "\n${BOLD}What would you like to do?${RESET}\n"
    echo -e "  ${BOLD}[A]${RESET}  Remove all removable kernels (+ related headers/modules)"
    echo -e "  ${BOLD}[S]${RESET}  Select kernels to remove individually"
    echo -e "  ${BOLD}[Q]${RESET}  Quit — make no changes"
    echo ""
    read -rp "Choice [A/S/Q]: " choice

    case "${choice,,}" in
        a) remove_kernels "${REMOVABLE[@]}" ;;
        s) select_and_remove "${REMOVABLE[@]}" ;;
        *) echo -e "\n${YELLOW}Aborted. No changes made.${RESET}\n"; exit 0 ;;
    esac
}

# ── Remove a list of kernel packages (+ their related packages) ───────────────
remove_kernels() {
    local input_pkgs=("$@")
    local to_remove=()

    for pkg in "${input_pkgs[@]}"; do
        ver="${pkg#linux-image-}"
        to_remove+=("$pkg")
        while IFS= read -r related; do
            [[ -n "$related" ]] && to_remove+=("$related")
        done < <(get_related_packages "$ver")
    done

    # Deduplicate
    mapfile -t to_remove < <(printf '%s\n' "${to_remove[@]}" | sort -u)

    echo ""
    echo -e "${BOLD}Packages queued for removal:${RESET}"
    for p in "${to_remove[@]}"; do
        echo -e "  ${RED}- ${p}${RESET}"
    done
    echo ""

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would execute:${RESET}"
        echo -e "  ${DIM}${SUDO} apt-get purge -y ${to_remove[*]}${RESET}"
        echo -e "  ${DIM}${SUDO} apt-get autoremove -y${RESET}"
        return
    fi

    if ! $AUTO_YES; then
        read -rp "Confirm removal of ${#to_remove[@]} package(s)? [y/N]: " confirm
        [[ "${confirm,,}" != "y" ]] && echo -e "${YELLOW}Cancelled. No changes made.${RESET}" && return
    fi

    echo ""
    $SUDO apt-get purge -y "${to_remove[@]}"
    echo ""
    $SUDO apt-get autoremove -y

    echo ""
    echo -e "${GREEN}Done.${RESET} Updating GRUB..."
    $SUDO update-grub 2>/dev/null || echo -e "${DIM}(update-grub not found — you may need to refresh your bootloader manually)${RESET}"
    echo ""
}

# ── Per-kernel interactive selection ─────────────────────────────────────────
select_and_remove() {
    local pkgs=("$@")
    local selected=()

    echo ""
    echo -e "${BOLD}Select kernels to remove:${RESET} (y = yes, n = skip, q = quit)\n"

    for pkg in "${pkgs[@]}"; do
        read -rp "  Remove ${RED}${pkg}${RESET}? [y/N/q]: " ans
        case "${ans,,}" in
            y) selected+=("$pkg") ;;
            q) break ;;
        esac
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo -e "\n${YELLOW}Nothing selected. No changes made.${RESET}\n"
        return
    fi

    remove_kernels "${selected[@]}"
}

main "$@"

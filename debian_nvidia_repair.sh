#!/usr/bin/env bash
set -euo pipefail

# AI Assisted code - Working by AppaTalks
# Install latest Nvidia-Drivers after run.
# - 2025
############################################
# NVIDIA + CUDA clean-install for Debian
# - Stops GUI, purges old drivers/run-file
# - Enables non-free repos
# - Detects correct driver branch
# - Installs driver, DKMS, headers, CUDA
############################################

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌  Run this script with sudo or as root." >&2
    exit 1
  fi
}

stop_display_manager() {
  echo "⏹  Stopping display manager…"
  for svc in gdm3 sddm lightdm; do
    systemctl stop "$svc" 2>/dev/null || true
  done
}

uninstall_runfile_if_any() {
  if command -v nvidia-uninstall &>/dev/null; then
    echo "🧹  Removing previous .run-file driver…"
    yes | nvidia-uninstall || true
  fi
}

purge_apt_drivers() {
  echo "🧽  Purging existing Debian NVIDIA/CUDA packages…"
  apt-get remove --purge -y '^nvidia.*' 'cuda-*' 'libcuda*' || true
  apt-get autoremove --purge -y
}

enable_nonfree_repos() {
  echo "📝  Ensuring non-free repos exist…"
  codename=$(lsb_release -cs)
  repo_line="deb http://deb.debian.org/debian ${codename} main contrib non-free non-free-firmware"
  grep -qF "$repo_line" /etc/apt/sources.list || \
    echo "$repo_line" >> /etc/apt/sources.list
  apt-get update
}

detect_driver_branch() {
  echo "🔍  Detecting correct driver branch…"
  apt-get install -y nvidia-detect
  if nvidia-detect | grep -q "nvidia-tesla-470-driver"; then
    echo "nvidia-tesla-470-driver"
  else
    echo "nvidia-driver"
  fi
}

install_driver_and_cuda() {
  local pkg=$1
  echo "📦  Installing $pkg + CUDA toolkit…"
  apt-get install -y build-essential dkms linux-headers-$(uname -r) "$pkg" nvidia-cuda-toolkit
  apt-mark hold "$pkg" nvidia-cuda-toolkit
}

main() {
  need_root
  stop_display_manager
  uninstall_runfile_if_any
  purge_apt_drivers
  enable_nonfree_repos
  driver_pkg=$(detect_driver_branch)
  install_driver_and_cuda "$driver_pkg"
  echo "✅  Done. Reboot to load the new NVIDIA kernel module."
}

main "$@"


###
# After
# sudo apt-mark hold nvidia-driver nvidia-driver-libs nvidia-driver-bin libcuda1
# 
# sudo apt-get update
# sudo apt-get install --reinstall nvidia-driver-libs:amd64 nvidia-driver-bin
# sudo ldconfig          # rebuild linker cache
# sudo apt install nvidia-cuda-toolkit.


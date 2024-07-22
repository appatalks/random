#!/bin/bash

# Update package database
yay -Sy --noconfirm

# Get the list of installed packages, excluding 'aur/ltfs-quantum'
packages=$(pacman -Qq | grep -v 'ltfs-quantum')

for package in $packages; do
  echo "Attempting to update $package..."
  yay -S --needed --noconfirm $package
  if [ $? -ne 0 ]; then
    echo "Failed to update $package. Skipping..."
  else
    echo "$package updated successfully."
  fi
done

# Full system upgrade excluding already failed packages and 'aur/ltfs-quantum'
yay -Su --needed --noconfirm --ignore ltfs-quantum

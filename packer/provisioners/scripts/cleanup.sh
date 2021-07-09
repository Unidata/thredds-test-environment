#!/usr/bin/bash
set -ex

# Check that we are root, and if not, use sudo to run commands.
SUDO_CMD=""
if [ "$EUID" -ne 0 ]; then
    SUDO_CMD="sudo"
fi

# Remove dangling dependencies.
${SUDO_CMD} apt autoremove --purge --yes

# Clear out the apt cache.
${SUDO_CMD} apt-get clean --yes

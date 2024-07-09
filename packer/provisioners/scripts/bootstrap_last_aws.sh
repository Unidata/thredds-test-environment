#!/usr/bin/bash
set -ex

# Check that we are root, and if not, use sudo to run commands.
SUDO_CMD=""
if [ "$EUID" -ne 0 ]; then
    SUDO_CMD="sudo"
fi

# Need openjdk-xx-jre-headless so that jenkins can connect to worker nodes
# using this ami.
${SUDO_CMD} apt install --yes openjdk-17-jre-headless

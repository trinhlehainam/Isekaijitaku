#!/bin/bash

# https://nodejs.org/en/download
# Download and run the NodeSource setup script
echo "Setting up NodeSource repository..."
curl -o- https://fnm.vercel.app/install | bash

# Install NodeJS
echo "Installing NodeJS..."
fnm install 22

# Solve corepack error: Cannot Find Matching Keyid
# https://vercel.com/guides/corepack-errors-github-actions#how-to-fix-it
npm install -g corepack@latest

# Download and install pnpm:
echo "Installing pnpm..."
corepack enable pnpm

# Verify installation
echo "Verifying NodeJS installation..."
node --version
npm --version
pnpm --version

echo "NodeJS installation completed successfully!"

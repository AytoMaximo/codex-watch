---
name: codex-watch
description: Bridge your Codex CLI session to the watch app on Apple Watch
author: shobhit
version: 0.1.0
---

# Codex Watch Bridge

Starts a local bridge server that connects your active Codex CLI session
to the iOS/watchOS app.

## What it does
- Runs a Node.js bridge server on your LAN
- Registers Codex hooks for real-time event forwarding
- Generates a 6-digit pairing code for the iPhone app
- Enables voice commands from your Apple Watch

## Usage
Run the bridge and install hooks with `./skill/setup-hooks.sh`.
Enter the pairing code in the iPhone app.

## Setup
The bridge requires Node.js 18+ and the `node-pty` package.
Run the setup script: `cd skill/bridge && npm install`

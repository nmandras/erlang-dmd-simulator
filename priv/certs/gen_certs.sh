#!/usr/bin/env bash
# Generate a self-signed certificate/key pair for local TLS testing.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$DIR/server.key" \
  -out "$DIR/server.pem" \
  -days 365 \
  -subj "/CN=localhost"

echo "Wrote $DIR/server.pem and $DIR/server.key"

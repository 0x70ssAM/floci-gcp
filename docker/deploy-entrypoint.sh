#!/bin/sh
# Auto-detects this host's public IP at container start and exports it as
# FLOCI_GCP_HOSTNAME / FLOCI_GCP_BASE_URL before starting the emulator, so
# URLs it returns (signed GCS URLs, etc.) resolve correctly from outside no
# matter what IP this VM/sandbox instance was handed this time around.
#
# Skipped entirely if FLOCI_GCP_HOSTNAME is already set via `environment:`,
# so an explicit override always wins over detection.
set -eu

if [ -z "${FLOCI_GCP_HOSTNAME:-}" ]; then
    PUBLIC_IP=""

    # GCP metadata server
    PUBLIC_IP="$(curl -fsS -m 2 -H 'Metadata-Flavor: Google' \
        'http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip' \
        2>/dev/null || true)"

    # AWS metadata server (IMDSv1; works on instances that allow it)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="$(curl -fsS -m 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
    fi

    # Azure metadata server
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="$(curl -fsS -m 2 -H 'Metadata: true' \
            'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text' \
            2>/dev/null || true)"
    fi

    # Generic external IP lookups (any cloud/VM/sandbox without a metadata service)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="$(curl -fsS -m 3 https://api.ipify.org 2>/dev/null || true)"
    fi
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="$(curl -fsS -m 3 https://ifconfig.me 2>/dev/null || true)"
    fi

    if [ -n "$PUBLIC_IP" ]; then
        echo "deploy-entrypoint: detected public IP: $PUBLIC_IP"
        export FLOCI_GCP_HOSTNAME="$PUBLIC_IP"
    else
        echo "deploy-entrypoint: could not detect a public IP; falling back to localhost" >&2
        export FLOCI_GCP_HOSTNAME="localhost"
    fi
fi

if [ -z "${FLOCI_GCP_BASE_URL:-}" ]; then
    export FLOCI_GCP_BASE_URL="http://${FLOCI_GCP_HOSTNAME}"
fi

exec /app/application -Dquarkus.http.host=0.0.0.0

#!/bin/bash
set -e

echo "STRT: $(basename "${0}")"

# make sure we run as root
if [ ! "$(id -u)" -eq 0 ]; then
  echo "FAIL: $(basename "${0}"): must be run as root" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  echo "INFO: no arguments provided"
elif [ "$#" -eq 2 ]; then
  echo "INFO: using arguments as: <DEPLOYMENT_ENVIRONMENT_NAME> <GENKEY_TOKEN>"
  if [[ ! "${1:-}" =~ ^[a-z][a-z,0-9,-\.]{0,61}[a-z,0-9]$ ]]; then
    echo "FAIL: Invalid DEPLOYMENT_ENVIRONMENT_NAME, arg1: (${1})"
    echo "FAIL: The DEPLOYMENT_ENVIRONMENT_NAME should be: ^[a-z][a-z,0-9,-]{0,61}[a-z,0-9]$"
    exit 1
  fi
  if [[ ! "${2:-}" =~ ^[a-zA-Z0-9]{8,61}$ ]]; then
    echo "FAIL: Invalid GENKEY_TOKEN, arg2: (${2})"
    echo "FAIL: The GENKEY_TOKEN should be: ^[a-zA-Z0-9]{8,61}$"
    exit 1
  fi
  cat << EOF | tee /etc/otelcol-contrib/.env
  DEPLOYMENT_ENVIRONMENT_NAME="${1}"
  GENKEY_TOKEN="${2}"
EOF
fi

function disable_if_exists() {
    if systemctl list-unit-files "${1}" >/dev/null 2>&1; then
        echo "INFO: Service (${1}) exists."
        if systemctl disable --now "${1}"; then
          echo "INFO: Service (${1}) disabled"
        else
          echo "FAIL: Cannot disable(${1})"
          exiit 1
        fi
    else
        echo "INFO: Service (${1}) does not exist, Nothing to do."
    fi
}
disable_if_exists "opentelemetry-collector.service"
disable_if_exists "otelcol-contrib.service"

readonly otel_ver="0.144.0"
readonly des="otelcol-contrib-${otel_ver}-1.x86_64"
if rpm -q "${des}" >/dev/null; then
  echo "INFO: package is installed with the correct version ${des}"
else
  echo "WARN: removing simular packages if exists"
  rpm -qa --queryformat '%{NAME}\n' | grep -E "^(otelcol|opentelemetry-collector).*" | xargs -r rpm -veh
  readonly rpm_file="otelcol-contrib_${otel_ver}_linux_amd64.rpm"
  curl -C -  --output-dir /tmp/ -OL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${otel_ver}/${rpm_file}"
  rpm -ivh "/tmp/${rpm_file}"
  disable_if_exists "otelcol-contrib.service"
fi

rm -vrf /etc/systemd/system/otelcol-contrib.service.d/genkey-*.conf

echo "INFO: add .env as an additional EnvironmentFile"
mkdir -vp /etc/systemd/system/otelcol-contrib.service.d/
cat << EOF | tee /etc/systemd/system/otelcol-contrib.service.d/genkey-override.conf
[Service]
EnvironmentFile=/etc/otelcol-contrib/.env
EOF

now="$(date +'%Y%m%d_%H%M%S')"
readonly now
readonly config_new="/tmp/otelcol-contrib-config-${now}.yaml"
readonly config_existing="/etc/otelcol-contrib/config.yaml"
readonly GENKEY_OTEL_CONFIG_NAME="${GENKEY_OTEL_CONFIG_NAME:-linux-native.yaml}"
echo "INFO: using GENKEY_OTEL_CONFIG_NAME: '${GENKEY_OTEL_CONFIG_NAME}'"
curl -fL "https://raw.githubusercontent.com/genkeydev/goodies/refs/heads/main/otel/${GENKEY_OTEL_CONFIG_NAME}" -o "/tmp/otelcol-contrib-config-${now}.yaml"

if [ ! -f "${config_existing}" ]; then
  echo "INFO: otel config added"
  cp -v "${config_new}" "${config_existing}"
elif cmp --silent -- "${config_existing}" "${config_new}"; then
  echo "INFO: configs are identical"
  rm -v "${config_new}"
else
  echo "WARN: otel config changed"
  cp -v "${config_existing}" "${config_existing}-${now}"
  cp -v "${config_new}" "${config_existing}"
fi

systemctl daemon-reload
systemctl enable --now otelcol-contrib.service

echo "DONE: please validate with: journalctl -u otelcol-contrib.service -f"

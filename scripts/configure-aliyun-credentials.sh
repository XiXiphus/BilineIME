#!/bin/bash
set -euo pipefail

DOMAIN="${BILINE_DEFAULTS_DOMAIN:-io.github.xixiphus.inputmethod.BilineIME.dev}"
SERVICE="BilineIME.AlibabaMachineTranslation"
ACCESS_KEY_ID_ACCOUNT="accessKeyId"
ACCESS_KEY_SECRET_ACCOUNT="accessKeySecret"
DEFAULT_REGION="cn-hangzhou"
DEFAULT_ENDPOINT="https://mt.cn-hangzhou.aliyuncs.com"
CREDENTIAL_FILE="${BILINE_CREDENTIAL_FILE:-$HOME/Library/Containers/$DOMAIN/Data/Library/Application Support/BilineIME/alibaba-credentials.json}"

usage() {
  cat <<EOF
usage: $0 [configure|status|clear]

configure  Prompt for Alibaba Cloud AccessKey values and store them in Keychain.
status     Print provider and credential presence without revealing secrets.
clear      Remove Biline Alibaba credentials from Keychain and provider defaults.

Environment:
  BILINE_DEFAULTS_DOMAIN  Defaults domain to configure. Defaults to dev IME.
EOF
}

read_secret() {
  local prompt="$1"
  local value=""
  printf "%s" "$prompt" >&2
  IFS= read -rs value
  printf "\n" >&2
  printf "%s" "$value"
}

read_plain_default() {
  local prompt="$1"
  local fallback="$2"
  local value=""
  printf "%s [%s]: " "$prompt" "$fallback" >&2
  IFS= read -r value
  if [[ -z "$value" ]]; then
    printf "%s" "$fallback"
  else
    printf "%s" "$value"
  fi
}

store_keychain_password() {
  local account="$1"
  local value="$2"
  security add-generic-password \
    -s "$SERVICE" \
    -a "$account" \
    -w "$value" \
    -U >/dev/null
}

keychain_password_length() {
  local account="$1"
  local value=""
  if value="$(security find-generic-password -s "$SERVICE" -a "$account" -w 2>/dev/null)"; then
    printf "%s" "${#value}"
  else
    printf "missing"
  fi
}

defaults_value() {
  local key="$1"
  defaults read "$DOMAIN" "$key" 2>/dev/null || true
}

credential_file_lengths() {
  if [[ ! -f "$CREDENTIAL_FILE" ]]; then
    echo "credential_file=missing"
    return
  fi
  python3 - "$CREDENTIAL_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    print("credential_file=unreadable")
    raise SystemExit(0)

access_key_id = str(data.get("accessKeyId", ""))
access_key_secret = str(data.get("accessKeySecret", ""))
print(f"credential_file={path}")
print(f"credential_file_accessKeyId={len(access_key_id) if access_key_id else 'missing'}")
print(f"credential_file_accessKeySecret={len(access_key_secret) if access_key_secret else 'missing'}")
PY
}

configure() {
  local access_key_id access_key_secret region endpoint
  access_key_id="$(read_secret "Alibaba AccessKey ID: ")"
  access_key_secret="$(read_secret "Alibaba AccessKey Secret: ")"
  region="$(read_plain_default "Alibaba region" "$DEFAULT_REGION")"
  endpoint="$(read_plain_default "Alibaba endpoint" "$DEFAULT_ENDPOINT")"

  if [[ -z "$access_key_id" || -z "$access_key_secret" ]]; then
    echo "AccessKey ID and secret are required." >&2
    exit 1
  fi

  store_keychain_password "$ACCESS_KEY_ID_ACCOUNT" "$access_key_id"
  store_keychain_password "$ACCESS_KEY_SECRET_ACCOUNT" "$access_key_secret"
  unset access_key_id access_key_secret

  defaults write "$DOMAIN" BilineTranslationProvider aliyun
  defaults write "$DOMAIN" BilineAlibabaRegionId "$region"
  defaults write "$DOMAIN" BilineAlibabaEndpoint "$endpoint"
  killall cfprefsd >/dev/null 2>&1 || true

  echo "Alibaba translation provider configured for $DOMAIN."
  status
}

status() {
  local provider region endpoint access_key_id_length access_key_secret_length
  provider="$(defaults_value BilineTranslationProvider)"
  region="$(defaults_value BilineAlibabaRegionId)"
  endpoint="$(defaults_value BilineAlibabaEndpoint)"
  access_key_id_length="$(keychain_password_length "$ACCESS_KEY_ID_ACCOUNT")"
  access_key_secret_length="$(keychain_password_length "$ACCESS_KEY_SECRET_ACCOUNT")"

  echo "domain=$DOMAIN"
  echo "provider=${provider:-<missing>}"
  echo "region=${region:-<missing>}"
  echo "endpoint=${endpoint:-<missing>}"
  credential_file_lengths
  echo "keychain_accessKeyId=${access_key_id_length}"
  echo "keychain_accessKeySecret=${access_key_secret_length}"
  if defaults read "$DOMAIN" BilineAlibabaAccessKeyId >/dev/null 2>&1; then
    echo "defaults_accessKeyId=present"
  else
    echo "defaults_accessKeyId=missing"
  fi
  if defaults read "$DOMAIN" BilineAlibabaAccessKeySecret >/dev/null 2>&1; then
    echo "defaults_accessKeySecret=present"
  else
    echo "defaults_accessKeySecret=missing"
  fi
}

clear() {
  rm -f "$CREDENTIAL_FILE" >/dev/null 2>&1 || true
  security delete-generic-password -s "$SERVICE" -a "$ACCESS_KEY_ID_ACCOUNT" >/dev/null 2>&1 || true
  security delete-generic-password -s "$SERVICE" -a "$ACCESS_KEY_SECRET_ACCOUNT" >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineTranslationProvider >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaRegionId >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaEndpoint >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaAccessKeyId >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaAccessKeySecret >/dev/null 2>&1 || true
  killall cfprefsd >/dev/null 2>&1 || true
  echo "Alibaba translation provider credentials cleared for $DOMAIN."
}

COMMAND="${1:-status}"
case "$COMMAND" in
  configure)
    configure
    ;;
  status)
    status
    ;;
  clear)
    clear
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

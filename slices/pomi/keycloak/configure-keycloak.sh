#!/usr/bin/env bash

set -euo pipefail

keycloak_url="${KEYCLOAK_INTERNAL_URL:-http://keycloak:8080}"
realm="${KEYCLOAK_REALM:-pomi}"
config_file=/tmp/pomi-kcadm.config
kcadm=/opt/keycloak/bin/kcadm.sh

authenticated=false
for ((attempt = 1; attempt <= 30; attempt++)); do
  if "$kcadm" config credentials \
    --config "$config_file" \
    --server "$keycloak_url" \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"; then
    authenticated=true
    break
  fi
  sleep 5
done

if [[ "$authenticated" != "true" ]]; then
  echo "Não foi possível autenticar no Keycloak após 30 tentativas." >&2
  exit 1
fi

if "$kcadm" get "realms/$realm" --config "$config_file" >/dev/null 2>&1; then
  "$kcadm" update "realms/$realm" \
    --config "$config_file" \
    -s enabled=true \
    -s registrationAllowed=true \
    -s registrationEmailAsUsername=true \
    -s loginWithEmailAllowed=true \
    -s duplicateEmailsAllowed=false \
    -s verifyEmail=false \
    -s bruteForceProtected=true \
    -s rememberMe=true \
    -s accessTokenLifespan=3600 \
    -s ssoSessionIdleTimeout=2592000 \
    -s ssoSessionMaxLifespan=2592000 \
    -s ssoSessionIdleTimeoutRememberMe=2592000 \
    -s ssoSessionMaxLifespanRememberMe=2592000 \
    -s loginTheme=pomi \
    -s emailTheme=pomi \
    -s displayName=POMI \
    -s internationalizationEnabled=true \
    -s 'supportedLocales=["pt-BR","en"]' \
    -s defaultLocale=pt-BR
else
  "$kcadm" create realms \
    --config "$config_file" \
    -s "realm=$realm" \
    -s enabled=true \
    -s registrationAllowed=true \
    -s registrationEmailAsUsername=true \
    -s loginWithEmailAllowed=true \
    -s duplicateEmailsAllowed=false \
    -s verifyEmail=false \
    -s bruteForceProtected=true \
    -s rememberMe=true \
    -s accessTokenLifespan=3600 \
    -s ssoSessionIdleTimeout=2592000 \
    -s ssoSessionMaxLifespan=2592000 \
    -s ssoSessionIdleTimeoutRememberMe=2592000 \
    -s ssoSessionMaxLifespanRememberMe=2592000 \
    -s loginTheme=pomi \
    -s emailTheme=pomi \
    -s displayName=POMI \
    -s internationalizationEnabled=true \
    -s 'supportedLocales=["pt-BR","en"]' \
    -s defaultLocale=pt-BR
fi

if [[ -n "${KEYCLOAK_SMTP_HOST:-}" ]]; then
  "$kcadm" update "realms/$realm" \
    --config "$config_file" \
    -s "smtpServer.host=$KEYCLOAK_SMTP_HOST" \
    -s "smtpServer.port=${KEYCLOAK_SMTP_PORT:-587}" \
    -s "smtpServer.auth=true" \
    -s "smtpServer.starttls=false" \
    -s "smtpServer.ssl=true" \
    -s "smtpServer.user=$KEYCLOAK_SMTP_USER" \
    -s "smtpServer.password=$KEYCLOAK_SMTP_PASSWORD" \
    -s "smtpServer.from=$KEYCLOAK_SMTP_USER" \
    -s "smtpServer.replyTo=$KEYCLOAK_SMTP_USER"
fi

reconcile_client() {
  local client_name="$1"
  local definition="/opt/keycloak/config/$client_name.json"
  local client_id

  client_id="$("$kcadm" get clients \
    --config "$config_file" \
    -r "$realm" \
    -q "clientId=$client_name" \
    --fields id | \
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | \
    head -n 1)"

  if [[ -n "$client_id" ]]; then
    "$kcadm" update "clients/$client_id" \
      --config "$config_file" \
      -r "$realm" \
      -f "$definition"
  else
    "$kcadm" create clients \
      --config "$config_file" \
      -r "$realm" \
      -f "$definition"
  fi
}

reconcile_client pomi-api
reconcile_client pomi-frontend
reconcile_client pomi-token-cli

rm -f "$config_file"

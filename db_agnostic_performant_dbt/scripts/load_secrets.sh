#!/usr/bin/env bash
# Export warehouse credentials from AWS Secrets Manager into $GITHUB_ENV (masked in logs).
# Secret "<prefix>/dbt/<target>" holds a JSON object whose keys are profile env var names.
set -euo pipefail
prefix="$1"; target="$2"
json=$(aws secretsmanager get-secret-value --secret-id "${prefix}/dbt/${target}" --query SecretString --output text)
salt=$(aws secretsmanager get-secret-value --secret-id "${prefix}/dbt/pii_salt" --query SecretString --output text)
echo "::add-mask::${salt}"
echo "DBT_PII_SALT=${salt}" >> "$GITHUB_ENV"
for key in $(jq -r 'keys[]' <<<"$json"); do
  value=$(jq -r --arg k "$key" '.[$k]' <<<"$json")
  echo "::add-mask::${value}"
  if [[ "$value" == *$'\n'* ]]; then
    { echo "${key}<<__EOF__"; echo "$value"; echo "__EOF__"; } >> "$GITHUB_ENV"
  else
    echo "${key}=${value}" >> "$GITHUB_ENV"
  fi
done

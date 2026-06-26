#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRAPE_TEMPLATE="$ROOT/monitoring/prometheus/tether-scrape.tmpl.yml"
ALERT_TEMPLATE="$ROOT/monitoring/alertmanager/tether-alertmanager.tmpl.yml"
SCRAPE_OUT="$ROOT/monitoring/prometheus/tether-scrape.generated.yml"
ALERT_OUT="$ROOT/monitoring/alertmanager/tether-alertmanager.generated.yml"

staging_base_url="${TETHER_STAGING_BASE_URL:-http://localhost:8080}"
production_base_url="${TETHER_PRODUCTION_BASE_URL:-$staging_base_url}"
slack_webhook="${SLACK_WEBHOOK_URL:-https://hooks.slack.com/services/placeholder}"
pagerduty_routing_key="${PAGERDUTY_ROUTING_KEY:-00000000000000000000000000000000}"

sed -e "s#{{STAGING_BASE_URL}}#$staging_base_url#g" \
  -e "s#{{PRODUCTION_BASE_URL}}#$production_base_url#g" \
  "$SCRAPE_TEMPLATE" > "$SCRAPE_OUT"

sed -e "s#{{SLACK_WEBHOOK_URL}}#$slack_webhook#g" \
  -e "s#{{PAGERDUTY_ROUTING_KEY}}#$pagerduty_routing_key#g" \
  "$ALERT_TEMPLATE" > "$ALERT_OUT"

echo "rendered=$SCRAPE_OUT"
echo "rendered=$ALERT_OUT"

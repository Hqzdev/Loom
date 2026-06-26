# Tether observability stack

1. Render concrete env-aware configs (required)

```bash
cd monitoring
TETHER_STAGING_BASE_URL=<staging-url> \
TETHER_PRODUCTION_BASE_URL=<production-url> \
SLACK_WEBHOOK_URL=<slack-webhook> \
PAGERDUTY_ROUTING_KEY=<pagerduty-key> \
./scripts/p1-observability-render.sh
```

2. Start infrastructure

```bash
cd monitoring
docker compose up -d
```

3. Open dashboards

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Alertmanager: `http://localhost:9093`

4. Edit alert routing

Rendered files used by `docker-compose`:
- `prometheus/tether-scrape.generated.yml`
- `alertmanager/tether-alertmanager.generated.yml`

Re-run `p1-observability-render.sh` if webhook, routing key, or base URLs change.

Use your ops secret mechanism (CI secrets or environment injection) and never
commit real endpoint secrets in repo.

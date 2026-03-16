# Notification Router (`scripts/notify.js`)

Multi-channel notification routing for Squad. Directs messages to the right channel based on content tags or keyword matching.

## Quick Start

```bash
# Explicit channel tag
echo "CHANNEL: wins 🎉 PR #42 merged!" | node scripts/notify.js --provider console

# Auto-routed by keyword (detects "merged" → wins channel)
echo "🎉 PR #42 merged!" | node scripts/notify.js --provider console

# Via --message flag
node scripts/notify.js --message "CHANNEL: alerts ⚠️ CI pipeline failed" --provider console
```

## How Routing Works

1. **Explicit tag** — If message starts with `CHANNEL: <key>`, it goes to that channel
2. **Keyword match** — The `routing` map in config matches keywords in the message body to channels
3. **Default fallback** — If no match, routes to `defaultChannel` from config

## Providers

| Provider     | Description                                  | Use Case                     |
|-------------|----------------------------------------------|------------------------------|
| `console`   | Prints to stdout                             | Testing, local dev, logging  |
| `webhook`   | HTTP POST to Teams/Slack incoming webhook    | Production notifications     |
| `teams-mcp` | Outputs JSON command for Teams MCP tooling   | Agent-driven posting         |

## Configuration

Config lives at `.squad/notification-routes.json`:

```json
{
  "defaultChannel": "general",
  "provider": "webhook",
  "channels": {
    "general": { "name": "General", "webhookUrl": "${SQUAD_WEBHOOK_GENERAL}" },
    "wins":    { "name": "Wins",    "webhookUrl": "${SQUAD_WEBHOOK_WINS}" }
  },
  "routing": {
    "wins": ["merged", "closed", "milestone", "celebration"]
  }
}
```

- **`defaultChannel`** — Fallback when no routing match is found
- **`provider`** — Default provider (`webhook`, `console`, `teams-mcp`)
- **`channels`** — Channel definitions with names and webhook URLs
- **`routing`** — Keyword-to-channel mapping for auto-detection

### Environment Variable Substitution

Webhook URLs support `${VAR_NAME}` syntax. Set env vars for your webhook URLs:

```bash
export SQUAD_WEBHOOK_GENERAL="https://your-org.webhook.office.com/..."
export SQUAD_WEBHOOK_WINS="https://your-org.webhook.office.com/..."
```

## CLI Options

```
--message, -m <text>   Message to send (reads stdin if omitted)
--provider, -p <type>  Override provider: webhook | teams-mcp | console
--config, -c <path>    Custom config path (default: .squad/notification-routes.json)
--help, -h             Show help
```

## Graceful Degradation

If a webhook call fails, the system automatically falls back to console output. This ensures notifications are never silently lost.

## Integration Examples

**From a GitHub Action or script:**
```bash
echo "CHANNEL: pr-code 🔍 Review requested on PR #${PR_NUMBER}" | node scripts/notify.js
```

**From an agent pipeline:**
```bash
node scripts/notify.js -m "CHANNEL: alerts ⚠️ Ralph health check failed" -p webhook
```

**Programmatic usage (Node.js):**
```js
const { dispatch, loadConfig } = require('./scripts/notify.js');
const config = loadConfig('.squad/notification-routes.json');
await dispatch('CHANNEL: wins 🎉 Milestone reached!', config, 'console');
```

## Adding a New Channel

1. Add the channel to `.squad/notification-routes.json` under `channels`
2. Optionally add routing keywords under `routing`
3. Set the webhook URL env var if using `webhook` provider

## Design Principles

- **Zero dependencies** — Uses only Node.js built-ins
- **Provider-agnostic** — Swap providers without changing message code
- **Configuration-driven** — All routing logic lives in JSON
- **Graceful degradation** — Console fallback on provider failure

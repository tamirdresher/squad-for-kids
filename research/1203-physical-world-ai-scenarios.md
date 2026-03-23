# Physical World AI Extensions: House Automation Scenarios & Prototypes

**Issue:** [#1203](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1203)  
**Author:** B'Elanna (Infrastructure Expert)  
**Date:** 2026-03-22  
**Status:** Research Complete

---

## Executive Summary

The AI squad can reach beyond the screen into the physical world at near-zero marginal cost using commodity AliExpress hardware, Home Assistant, and MCP/REST bridges. No electrical expertise is required — every item here is plug-in only. A $60–80 starter kit is enough to automate heating, lighting, and appliances and give squad agents real-time sensor data.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Hardware Options](#hardware-options)
3. [Top 5 Automation Scenarios](#top-5-automation-scenarios)
4. [Starter Kit Bill of Materials](#starter-kit-bill-of-materials)
5. [Squad Integration Patterns](#squad-integration-patterns)
6. [MCP Server for Home Assistant](#mcp-server-for-home-assistant)
7. [`physical-world` Skill Design](#physical-world-skill-design)
8. [Safety Notes](#safety-notes)
9. [Quick Start Guide](#quick-start-guide)
10. [Cost Summary](#cost-summary)

---

## Architecture Overview

```
AliExpress Hardware
  (Smart plug / IR blaster / sensor)
       │  Zigbee/WiFi
       ▼
Home Assistant  ←──── Raspberry Pi 4 or old laptop/NUC
  (hass.io)
       │  REST API / WebSocket / MCP
       ▼
Squad MCP Server  (physical-world skill)
       │
       ▼
GitHub Copilot CLI / Squad Agents
  "Belanna, set heating to 22°C"
  "Ralph, check if I left the iron on"
  "Kes, turn off living room lights at midnight"
```

**Key principle:** Home Assistant is the universal glue. Every cheap device speaks Zigbee, Z-Wave, or WiFi; Home Assistant normalises them all into one REST API. Squad agents consume that API through a thin MCP skill.

---

## Hardware Options

### Tier 1 — WiFi Smart Plugs (Easiest, no hub needed)

| Device | Protocol | Price (AliExpress) | Notes |
|--------|----------|--------------------|-------|
| Sonoff S26R2 | WiFi (ESP8285) | ~$5–7 | Flash Tasmota for local control |
| BlitzWolf BW-SHP6 | WiFi (ESP8285) | ~$8 | Energy monitoring built-in |
| Gosund EP2 | WiFi (ESP8285) | ~$5 | 2-pack available for ~$9 |

Flash [Tasmota](https://tasmota.github.io) over-the-air (OTA) — no soldering required for newer models. Tasmota exposes an HTTP REST endpoint natively and integrates with Home Assistant via MQTT autodiscovery.

### Tier 2 — Zigbee Ecosystem (More reliable, requires hub)

| Device | Type | Price | Notes |
|--------|------|-------|-------|
| Sonoff Zigbee USB Dongle Plus | Hub | ~$15 | USB stick, plug into Pi/PC |
| IKEA Tradfri bulb E27 9W | Light | ~$10 | Works without IKEA hub via Zigbee2MQTT |
| Aqara WXKG01LM | Button | ~$7 | Trigger automations |
| Aqara WSDCGQ11LM | Temp + Humidity | ~$9 | Reports every 10 min |
| Sonoff ZBMINI | Inline switch | ~$8 | DO NOT use — requires wiring |
| MOES ZTS-EU-W | Smart plug EU | ~$12 | Safe plug-in only |

**Hub:** Zigbee USB dongle → Zigbee2MQTT (Docker container) → MQTT → Home Assistant. Zero cloud dependency after setup.

### Tier 3 — IR Blaster (Control AC/TV/etc.)

| Device | Protocol | Price | Notes |
|--------|----------|----|-------|
| Broadlink RM4 Mini | WiFi + IR | ~$12 | Controls any IR remote device |
| Xiaomi IR controller | WiFi + IR | ~$10 | Local API via python-broadlink |

Perfect for controlling existing split ACs, TVs, fans — no wiring, just plug in and point at the device.

### Tier 4 — ESP32/NodeMCU Custom (Advanced, for makers)

| Item | Price | Use case |
|------|-------|----------|
| ESP32 DevKit | ~$3 | Custom sensors, relays |
| DHT22 sensor | ~$2 | Temp + humidity |
| DS18B20 waterproof | ~$2 | Water pipe temperature |

Flash with [ESPHome](https://esphome.io/) — YAML-based, no C++ needed. Integrates natively with Home Assistant.

---

## Top 5 Automation Scenarios

### Scenario 1: Smart Heating Control (Split AC via IR)
**Goal:** "Belanna, set heating to 22°C" → AC turns on in heating mode at 22°C

**Hardware:** Broadlink RM4 Mini ($12) + existing split AC  
**Software:** Home Assistant + `broadlink` integration + climate entity

**How it works:**
1. Broadlink learns your AC remote codes once
2. Home Assistant exposes a `climate` entity with temperature control
3. Squad agent calls `POST /api/services/climate/set_temperature`
4. Squad agent can also check Aqara temp sensor to confirm room reached target

**Cost:** ~$21 total (IR blaster $12 + temp sensor $9)

**Sample automation:**
```yaml
# In Home Assistant automation
alias: "Morning Pre-heat"
trigger:
  - platform: time
    at: "07:00:00"
action:
  - service: climate.set_temperature
    target:
      entity_id: climate.living_room_ac
    data:
      temperature: 22
      hvac_mode: heat
```

---

### Scenario 2: Lights Off When I Leave (Presence Detection)
**Goal:** All lights off when nobody is home

**Hardware:** 2x IKEA Tradfri bulbs ($10 each) + Zigbee dongle ($15)  
**Software:** Home Assistant + Zigbee2MQTT + phone presence via companion app (free)

**How it works:**
1. Home Assistant companion app on phone reports GPS/WiFi presence
2. When `device_tracker` goes `away`, automation turns off all `light.*` entities
3. Squad agent can query: "Are any lights on?" → `GET /api/states` filtered by domain=light

**Cost:** ~$35 (2 bulbs + dongle)

---

### Scenario 3: Iron/Kettle Forgot-It-On Alert
**Goal:** Alert via Teams if appliance draws power for >30 minutes

**Hardware:** BlitzWolf BW-SHP6 smart plug with energy monitoring ($8)  
**Software:** Home Assistant + Tasmota + Teams webhook

**How it works:**
1. Smart plug reports wattage in real time
2. HA automation triggers if appliance power > 50W for >30 minutes
3. Home Assistant calls a webhook that posts to Teams via squad notification channel
4. Ralph (the squad monitor) can query: "Is the iron on?" → checks plug wattage

**Cost:** ~$8

**Sample HA automation:**
```yaml
alias: "Iron left on alert"
trigger:
  - platform: numeric_state
    entity_id: sensor.iron_plug_power
    above: 50
    for:
      minutes: 30
action:
  - service: notify.teams_webhook
    data:
      message: "⚠️ Iron has been on for 30+ minutes!"
```

---

### Scenario 4: Morning Routine Automation
**Goal:** "Kes, start my morning routine" → coffee maker on, lights dim warm, heating to 21°C

**Hardware:** 1x smart plug for coffee maker ($7) + IR blaster for AC ($12) + 1 Tradfri bulb ($10)  
**Software:** Home Assistant scene + squad skill trigger

**How it works:**
1. Home Assistant `scene.morning_routine` activates: plug on, bulb warm white 40%, AC heat 21°C
2. Squad agent calls `POST /api/services/scene/turn_on` with scene entity_id
3. Can be time-triggered or voice/chat triggered

**Cost:** ~$29

---

### Scenario 5: Real-Time Environmental Dashboard
**Goal:** Squad agents can answer "Is it too hot in the server room?" / "What's the bedroom humidity?"

**Hardware:** 2x Aqara WSDCGQ11LM temp+humidity sensors ($9 each)  
**Software:** Home Assistant + sensor entities + Grafana (optional, free)

**How it works:**
1. Sensors report every 10 minutes via Zigbee
2. `GET /api/states/sensor.bedroom_temperature` returns current reading
3. Squad agents can monitor and alert if values cross thresholds
4. Grafana dashboard shows historical trends (Home Assistant has built-in history)

**Cost:** ~$33 (2 sensors + dongle already counted)

---

## Starter Kit Bill of Materials

**Total: ~$62 (under $80 shipped)**

| # | Item | Qty | Unit Price | Total | Purpose |
|---|------|-----|-----------|-------|---------|
| 1 | Sonoff Zigbee USB Dongle Plus | 1 | $15 | $15 | Zigbee hub |
| 2 | Aqara WSDCGQ11LM (temp+humidity) | 2 | $9 | $18 | Sensors |
| 3 | MOES ZTS-EU-W smart plug | 2 | $12 | $24 | Appliance control |
| 4 | Broadlink RM4 Mini (IR) | — | — | — | Optional: +$12 if you have AC |
| 5 | Raspberry Pi Zero 2W (or use spare PC) | 1 | $15 | $15 | Home Assistant host |
| — | MicroSD 16GB | 1 | $4 | $4 | HA OS |
| — | USB power supply | 1 | $5 | $5 | Pi power |

**Subtotal (no IR):** $62  
**Subtotal (with IR blaster):** $74

> **Note:** If you have an old PC, NUC, or laptop that runs 24/7 — skip the Pi. Home Assistant runs in Docker on any Linux/Windows machine.

---

## Squad Integration Patterns

### Pattern 1: Direct REST API Call

The Home Assistant REST API requires a Long-Lived Access Token (LLAT). Store it as a GitHub/squad secret.

```bash
# Turn on a switch
curl -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.iron_plug"}' \
  http://homeassistant.local:8123/api/services/switch/turn_on

# Query a sensor
curl -H "Authorization: Bearer $HA_TOKEN" \
  http://homeassistant.local:8123/api/states/sensor.bedroom_temperature
```

### Pattern 2: Home Assistant MCP Server

The [Home Assistant MCP server](https://github.com/home-assistant/mcp-server) (official, released 2025) exposes all HA entities as MCP tools. Add to your Copilot CLI config:

```json
// .copilot/mcp-servers.json
{
  "home-assistant": {
    "type": "sse",
    "url": "http://homeassistant.local:8123/mcp_server/sse",
    "headers": {
      "Authorization": "Bearer $HA_LONG_LIVED_TOKEN"
    }
  }
}
```

Once connected, Copilot CLI can natively call:
- `hassio_get_state` — query any entity
- `hassio_call_service` — trigger any service
- `hassio_list_entities` — discover all devices

### Pattern 3: Squad Agent Conversation Flow

```
User: "Belanna, the office is too cold"

B'Elanna:
  1. GET /api/states/sensor.office_temperature  → 17°C
  2. POST /api/services/climate/set_temperature  → {"temperature": 22, "hvac_mode": "heat"}
  3. Respond: "Office heating set to 22°C (was 17°C). Should reach target in ~20 min."
```

```
User: "Ralph, did I leave anything on?"

Ralph:
  1. GET /api/states  → filter for switch.* and sensor.*_power where state="on"
  2. Find: iron plug 1200W, been on 47 minutes
  3. Notify via Teams: "⚠️ Iron is on (1200W, 47 min). Turn off? [Yes/No]"
  4. On Yes: POST /api/services/switch/turn_off
```

---

## MCP Server for Home Assistant

### Option A: Official HA MCP Server (Recommended)

Available since Home Assistant 2024.11. Enable in `configuration.yaml`:

```yaml
mcp_server:
  allowed_entity_ids:
    - light.*
    - switch.*
    - climate.*
    - sensor.*
    - scene.*
```

Access at: `http://homeassistant.local:8123/mcp_server/sse`

This is the cleanest path — no extra code, officially maintained, works with any MCP client including GitHub Copilot CLI.

### Option B: Custom Squad Skill (REST wrapper)

If MCP direct connection isn't available (e.g., HA is on local LAN, CLI is remote), create a lightweight Python FastMCP server that proxies calls:

```python
# physical_world_mcp.py
from fastmcp import FastMCP
import httpx, os

HA_URL = os.environ["HA_URL"]  # e.g., http://homeassistant.local:8123
HA_TOKEN = os.environ["HA_TOKEN"]

mcp = FastMCP("physical-world")

@mcp.tool()
async def get_sensor(entity_id: str) -> dict:
    """Read a Home Assistant sensor or switch state."""
    async with httpx.AsyncClient() as c:
        r = await c.get(f"{HA_URL}/api/states/{entity_id}",
                        headers={"Authorization": f"Bearer {HA_TOKEN}"})
        return r.json()

@mcp.tool()
async def call_service(domain: str, service: str, entity_id: str, **kwargs) -> str:
    """Call any Home Assistant service."""
    async with httpx.AsyncClient() as c:
        payload = {"entity_id": entity_id, **kwargs}
        r = await c.post(f"{HA_URL}/api/services/{domain}/{service}",
                         headers={"Authorization": f"Bearer {HA_TOKEN}"},
                         json=payload)
        return "ok" if r.status_code == 200 else r.text

if __name__ == "__main__":
    mcp.run(transport="sse", host="0.0.0.0", port=9001)
```

---

## `physical-world` Skill Design

### Skill Metadata

```markdown
# physical-world skill

**Domain:** Home automation via Home Assistant
**Trigger phrases:**
- "turn on/off [device]"
- "set [room] to [temperature]"
- "is the [appliance] on?"
- "what's the temperature in [room]?"
- "run [scene name] routine"
- "check if I left [appliance] on"

**Environment Variables Required:**
- HA_URL: Home Assistant base URL (e.g., http://192.168.1.100:8123)
- HA_TOKEN: Long-Lived Access Token

**Capabilities:**
- Read any sensor state (temperature, humidity, power usage)
- Control switches and smart plugs
- Set climate/thermostat targets
- Activate scenes and scripts
- Check presence (is anyone home?)
- List all entities in a domain
```

### Skill File: `.squad/skills/physical-world/README.md`

```markdown
## physical-world

Controls physical devices via Home Assistant REST API / MCP.

### Usage
- Agents invoke this skill when users ask about physical environment
- Always confirm before turning off devices that may be intentionally on
- For heating/cooling: check current temperature first, report delta
- For power monitoring: alert if device on >30 minutes unexpectedly

### Safety Rules
1. NEVER turn off devices in an unknown state without asking
2. NEVER attempt to control devices not in the approved entity list
3. For multi-step actions (e.g., "morning routine"), confirm the full list first
4. Respect the `switch.guest_override` flag — don't automate when guests are home
```

---

## Safety Notes

> **This entire guide uses plug-in devices only. No wiring, no mains voltage exposure.**

### ✅ Safe Practices
- All devices connect via standard EU/US/IL plugs — no electrical panel access
- Smart plugs are rated for typical home appliances (typically 10–16A)
- IR blasters are USB-powered — zero risk
- Zigbee/WiFi sensors run on AA batteries or USB
- Home Assistant runs on Raspberry Pi or existing PC — low voltage DC only

### ⚠️ Things to Watch
- **Do not exceed smart plug current ratings** — check device label. Most handles 10A (2200W). Don't use for electric heaters >2000W without checking
- **Smart plugs + kettle/iron:** These are safe but ensure plug is rated (typically 16A needed for 2500W kettle — check specific model)
- **Fire safety:** Don't leave high-wattage unattended appliances on smart plugs for long automated sessions
- **Network security:** Use a dedicated IoT VLAN if possible. At minimum, change all default passwords and disable cloud features (Tasmota local-only mode)

### ❌ Never Do
- Do NOT flash smart switches that require opening the wall socket
- Do NOT use Sonoff ZBMINI or similar inline relays (requires electrical installation)
- Do NOT automate heating to extreme temperatures

---

## Quick Start Guide

### Step 1: Install Home Assistant (20 min)

**Option A — Raspberry Pi:**
```bash
# Download HA OS image for Pi Zero 2W
# Flash to microSD with Balena Etcher (free)
# Insert SD, power on Pi
# Visit http://homeassistant.local:8123 after 5 minutes
```

**Option B — Docker on Windows/Linux:**
```bash
docker run -d \
  --name homeassistant \
  --privileged \
  --restart unless-stopped \
  -v ha_config:/config \
  -p 8123:8123 \
  ghcr.io/home-assistant/home-assistant:stable
```

### Step 2: Add Zigbee USB Dongle (10 min)

```yaml
# In HA: Settings → Add-ons → Zigbee2MQTT
# Configuration:
serial:
  port: /dev/ttyUSB0
mqtt:
  server: mqtt://core-mosquitto
# Enable frontend, start add-on
# Pair devices by pressing their pairing button
```

### Step 3: Add Smart Plug (Tasmota) (5 min)

1. Power on smart plug while holding button → enters AP mode
2. Connect to `tasmota-XXXX` WiFi from phone
3. Enter your home WiFi credentials
4. In Tasmota web UI: `Configuration → Configure MQTT` → point to HA's MQTT broker
5. In HA: device appears automatically via MQTT autodiscovery

### Step 4: Generate HA Long-Lived Access Token (2 min)

1. HA → Profile (bottom left) → Long-Lived Access Tokens → Create Token
2. Copy token, save as squad secret:

```bash
gh secret set HA_TOKEN --repo tamirdresher_microsoft/tamresearch1
gh secret set HA_URL --repo tamirdresher_microsoft/tamresearch1
# Enter: http://[your-ha-ip]:8123
```

### Step 5: Enable MCP Server in HA (2 min)

```yaml
# configuration.yaml
mcp_server:
  allowed_entity_ids:
    - light.*
    - switch.*
    - climate.*
    - sensor.*
```

Restart HA. MCP endpoint ready at: `http://[ha-ip]:8123/mcp_server/sse`

### Step 6: Add to Copilot CLI Config (2 min)

```json
// ~/.config/github-copilot/mcp-servers.json (or squad config)
{
  "home-assistant": {
    "type": "sse",
    "url": "${HA_URL}/mcp_server/sse",
    "headers": {
      "Authorization": "Bearer ${HA_TOKEN}"
    }
  }
}
```

### Step 7: Test It

```bash
# In Copilot CLI chat:
"What's the temperature in the living room?"
"Turn on the kitchen switch"
"Set heating to 22 degrees"
```

**Total setup time: ~45 minutes for full stack.**

---

## Cost Summary

| Scenario | Hardware Cost | Setup Time | Difficulty |
|----------|--------------|------------|------------|
| 1. Heating via IR | $21 | 30 min | ⭐ Easy |
| 2. Lights + presence | $35 | 45 min | ⭐⭐ Medium |
| 3. Appliance safety alert | $8 | 20 min | ⭐ Easy |
| 4. Morning routine | $29 | 30 min | ⭐ Easy |
| 5. Environmental dashboard | $33 | 20 min | ⭐ Easy |
| **Starter kit (all 5)** | **~$62–74** | **~2 hours** | **⭐ Easy** |

> All prices are AliExpress estimates. Actual prices may vary ±20%. No electrical expertise needed.

---

## Key Recommendations

1. **Start with a smart plug + Tasmota** — $7, zero risk, immediate value (scenario 3)
2. **Get the Zigbee dongle** — unlocks the entire Zigbee ecosystem affordably
3. **Use the official HA MCP server** — don't build a custom bridge, it's already there
4. **Store HA_TOKEN as a squad secret** — never hardcode, rotate every 90 days
5. **Run HA on existing hardware first** — Docker on your PC before buying a Pi
6. **Add ESPHome ESP32 last** — only if you want custom sensors; not needed for basics

---

## References

- [Home Assistant REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Home Assistant MCP Server](https://developers.home-assistant.io/docs/mcp_server/)
- [Tasmota Documentation](https://tasmota.github.io/docs/)
- [Zigbee2MQTT](https://www.zigbee2mqtt.io/)
- [ESPHome](https://esphome.io/)
- [Broadlink Python Library](https://github.com/mjg59/python-broadlink)
- [FastMCP (Python MCP SDK)](https://github.com/jlowin/fastmcp)

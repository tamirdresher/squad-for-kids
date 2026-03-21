# Physical World AI Extensions: Scenarios & House Automation Prototypes

> **Issue:** #1203  
> **Author:** Seven (Research & Docs agent)  
> **Date:** 2026-06-22  
> **Status:** Research complete — prototype recommendations included

---

## Executive Summary

The Squad currently dominates the digital domain: emails, PRs, monitoring, code reviews, WhatsApp routing. This document explores the logical next frontier — **connecting Squad to the physical world** through low-cost, consumer-grade home automation hardware.

**Constraints honored throughout this document:**
- 💰 Budget: AliExpress-level (~$5–50 per component)
- 🔌 No electrical expertise — only plug-in, USB, or low-voltage DC devices
- 🏠 Practical home automation focus (heating, lighting, chores, comfort)
- 🤖 Integration via the same GitHub Copilot CLI / MCP pattern already in use

**Top recommendation:** Start with **Scenario A (Smart Plug Automation)** + **Scenario B (Temperature-Triggered Climate Control)**. Both are $15–30 total, zero wiring, and provide immediate Squad hooks.

---

## Table of Contents

1. [Integration Architecture Overview](#1-integration-architecture-overview)
2. [Scenario Catalog (10 Scenarios)](#2-scenario-catalog)
3. [Top 2 Prototype Recommendations](#3-top-2-prototype-recommendations)
4. [Step-by-Step Implementation Plans](#4-step-by-step-implementation-plans)
5. [Privacy & Security Analysis](#5-privacy--security-analysis)
6. [Cost Breakdown](#6-cost-breakdown)
7. [Rejected Approaches (Why They Don't Fit)](#7-rejected-approaches)
8. [Future Roadmap](#8-future-roadmap)

---

## 1. Integration Architecture Overview

### How Squad Connects to the Physical World

The Squad runs on a Windows machine (the "squad machine") as GitHub Copilot CLI agent sessions. Physical world integration follows this layered model:

```
┌─────────────────────────────────────────────────────────┐
│                    SQUAD LAYER                          │
│  Ralph (monitor) → Picard (orchestrate) → Data/Belanna  │
│  All running on squad machine via gh copilot CLI        │
└─────────────────────────────┬───────────────────────────┘
                              │ HTTP REST / MQTT / WebSocket
┌─────────────────────────────▼───────────────────────────┐
│                 IOT BRIDGE LAYER                        │
│  Home Assistant (local) OR direct cloud API             │
│  Runs on: Raspberry Pi Zero 2W ($15) OR same squad PC   │
└─────────────────────────────┬───────────────────────────┘
                              │ WiFi / Zigbee / Z-Wave
┌─────────────────────────────▼───────────────────────────┐
│               PHYSICAL DEVICE LAYER                     │
│  Smart plugs, sensors, IR blasters, LED strips, etc.    │
└─────────────────────────────────────────────────────────┘
```

### Three Integration Patterns

| Pattern | Use When | Latency | Complexity |
|---------|----------|---------|------------|
| **Direct Cloud API** | Device has a published API (e.g., Tuya, SwitchBot) | ~1s | Low |
| **Home Assistant Local** | Multiple devices, scenes, automations | ~100ms | Medium |
| **MCP Server for IoT** | Squad needs persistent device control as a tool | ~100ms | Medium |

### The MCP Approach (Recommended)

Squad agents already use MCP servers (GitHub MCP, ADO MCP). The cleanest extension is an **IoT MCP server** that exposes devices as tools:

```typescript
// Conceptual IoT MCP server tools
tools: [
  { name: "turn_on_device",  params: { device_id: string } },
  { name: "turn_off_device", params: { device_id: string } },
  { name: "get_sensor_reading", params: { sensor_id: string } },
  { name: "set_temperature",  params: { zone: string, celsius: number } },
  { name: "trigger_scene",    params: { scene_name: string } },
]
```

This means Ralph can say "It's 9 PM and Tamir's calendar shows he's home — trigger the 'evening wind-down' scene" without any custom glue code.

---

## 2. Scenario Catalog

### Scenario 1: Smart Plug Control (Power Scheduling) ⭐ TOP PICK

**Problem:** Devices left on (monitors, fans, desk lamps, phone chargers) waste power and require manual intervention. Squad has no physical presence.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| WiFi smart plug (Tuya-compatible) | Gosund SP111 or BlitzWolf BW-SHP6 | $5–8 |
| That's it — plugs into existing outlet | — | — |

**AliExpress search terms:** `"Tuya smart plug WiFi 16A monitor"` — look for ones labeled "Tuya" or "Smart Life" compatible.

**Software integration:**
1. Device uses Tuya cloud API (free tier: 1M API calls/month)
2. Local option: flash with **Tasmota** firmware via Tuya-Convert (no soldering, OTA flash)
3. Squad calls `POST /api/v1.0/devices/{device_id}/commands` with action `turnOnOff`
4. Or via Home Assistant REST API: `POST /api/services/switch/turn_on`

**Squad use cases:**
- Ralph detects Tamir hasn't moved (calendar gap + no WhatsApp activity) → turn off office monitors
- Morning routine trigger: turn on coffee machine at 7:30 AM (plug into coffee maker's manual brew button position)
- "Night mode": at 11 PM, cut power to all non-essential desk items
- Power monitoring: alert if device has been on for >4 hours ("Did you mean to leave the heater on?")

**Safety:** ✅ Zero electrical risk — plug-in only. Max 16A rated plugs handle any household device.

---

### Scenario 2: Temperature Sensor + Climate Notification ⭐ TOP PICK

**Problem:** Heating/cooling runs inefficiently. Squad doesn't know the physical environment state.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Zigbee temperature/humidity sensor | Sonoff SNZB-02 or Aqara WSDCGQ11LM | $8–12 |
| Zigbee USB dongle (coordinator) | SONOFF Zigbee 3.0 USB Dongle Plus | $12–15 |

**Total:** ~$20–27 for full temperature awareness in one room.

**AliExpress search terms:** `"Zigbee temperature sensor SNZB"` or `"Aqara temperature sensor Zigbee"`

**Software integration:**
1. Zigbee USB dongle plugs into squad machine (or Raspberry Pi)
2. **Zigbee2MQTT** (free, open-source) exposes all Zigbee devices as MQTT topics
3. Squad subscribes via MQTT: `zigbee2mqtt/living_room_sensor` → JSON payload with temp/humidity
4. OR use Home Assistant Zigbee integration (ZHA) — sensor appears as entity

**Squad use cases:**
- Temperature drops below 18°C → Squad sends Teams notification "Living room is getting cold — want me to schedule heating?"
- Humidity exceeds 70% → alert for mold risk in bathroom
- Track overnight temperature history → weekly report: "Your office averaged 24°C this week, ideal is 20–22°C"
- Cross-reference with Tamir's calendar: "You have a 3-hour meeting block at home — pre-warm room at 8 AM?"

**Safety:** ✅ Battery-powered sensors (CR2032). No mains connection. Zigbee dongle is just USB.

---

### Scenario 3: IR Blaster — Universal Remote Control

**Problem:** AC, TV, fan, projector all have IR remotes. Squad can't control them.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| WiFi IR blaster | BroadLink RM4 Mini or RM4 Pro | $15–20 |

**AliExpress search terms:** `"BroadLink RM4 mini IR blaster WiFi"`

**Software integration:**
1. BroadLink has a well-documented Python library: `broadlink` (pip install broadlink)
2. Learn IR codes once per device (point remote at blaster, press button)
3. Squad calls Python script or MCP tool: `ir_send(device="ac", command="heat_22")`
4. Home Assistant has native BroadLink integration

**Squad use cases:**
- Schedule AC: "Turn on heat mode at 22°C, 30 minutes before Tamir's work-from-home block starts"
- "I'm leaving in 10 minutes" (detected from calendar) → Squad turns off AC/TV automatically
- Voice-like control: Teams message "set ac 20" → Ralph routes to IR blaster
- Night automation: TV off at 11:30 PM if still on

**Safety:** ✅ IR blaster plugs into USB power (any phone charger). No mains wiring. IR is non-ionizing, completely safe.

**Note:** Works with any IR-controlled device — AC units (most Israeli homes have Mitsubishi/LG mini-splits), televisions, audio receivers, fans, projectors.

---

### Scenario 4: Smart LED Lighting (Mood / Productivity Modes)

**Problem:** Fixed lighting affects focus and mood. Squad has context about what Tamir is doing but can't adjust the environment.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Zigbee LED bulb (E27) | Innr RB 285C or Tuya Zigbee bulb | $8–12 per bulb |
| OR: WiFi LED strip (5m) | Govee or Tuya LED strip | $10–15 |

**AliExpress search terms:** `"Zigbee LED bulb E27 RGBW"` or `"Tuya WiFi LED strip RGBW 5m"`

**Software integration:**
- Zigbee bulbs: same dongle as Scenario 2, controlled via Zigbee2MQTT
- Tuya bulbs/strips: cloud API or local Tuya LAN protocol
- Home Assistant: `light.turn_on` service with brightness/color_temp/rgb_color

**Squad use cases:**
- **Deep Work mode** (calendar shows 2-hour block): cool white, 4000K, 80% brightness
- **Meeting mode** (video call on calendar): warm white, neutral, no harsh shadows
- **Break notification**: lights flash softly after 90 minutes of unbroken work
- **Evening wind-down**: automatically shift to 2700K warm at sunset
- **Alert mode**: red flash if a critical PR review is requested or ICM alert fires

**Safety:** ✅ Standard bulb sockets. LED bulbs run at low voltage internally.

---

### Scenario 5: Door/Window Sensors (Presence & Security)

**Problem:** Squad doesn't know if Tamir is home, which room he's in, or if windows/doors are open.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Zigbee door/window sensor | Sonoff SNZB-04 or Aqara door sensor | $7–10 each |

**AliExpress search terms:** `"Zigbee door sensor SNZB-04"` — uses same dongle as Scenario 2.

**Software integration:**
- Same Zigbee2MQTT stack
- Events: `open`, `closed` on MQTT → Squad subscribes

**Squad use cases:**
- Front door opens at unexpected time → notification via Teams
- "Tamir is home" detection (front door opened) → trigger "welcome home" scene (lights on, temperature check)
- "Tamir left" (front door closed, no re-open in 5 min) → Squad turns off all smart plugs, sets AC to eco mode
- Office window open + AC on → alert "Window is open, AC is running — want me to turn it off?"

**Safety:** ✅ Battery-powered magnets. No mains connection whatsoever.

---

### Scenario 6: Smart Button (Physical Squad Trigger)

**Problem:** Sometimes you want a single physical button to trigger a Squad workflow without opening a laptop or phone.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Zigbee smart button | Aqara WXKG11LM or IKEA TRADFRI button | $8–12 |

**AliExpress search terms:** `"Zigbee wireless mini switch button Aqara"`

**Software integration:**
- Button press events via Zigbee2MQTT: `single`, `double`, `hold`
- Map to Squad actions in Home Assistant automations or a lightweight webhook listener

**Squad use cases:**
- **Single press**: "Start focus session" → Deep Work lighting + mute all Teams notifications + start Pomodoro timer
- **Double press**: "I'm done with work" → Squad commits any open changes, sends EOD summary, turns off monitors
- **Hold**: "Emergency stop all" → Squad cancels pending automations, turns off all plugs
- Physical override for automation — no voice assistant, no app, just a button on the desk

**Safety:** ✅ Battery-powered. No mains connection.

---

### Scenario 7: CO2 / Air Quality Monitor

**Problem:** High CO2 levels (>1000 ppm) cause drowsiness and reduced cognitive performance. A developer's office with a closed door can hit 1500+ ppm in 2 hours.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| CO2 + TVOC sensor (MQTT-capable) | Aranet4 Home (~$100, premium) OR DIY: SCD40 sensor + ESP32 | $30–50 DIY |
| ESP32 dev board | ESP32-WROOM-32 | $5–8 |
| SCD40 CO2 sensor | Sensirion SCD40 | $20–25 |

**DIY approach:** SCD40 sensor + ESP32 running ESPHome firmware (no code, just YAML config) → auto-discovered in Home Assistant → MQTT available.

**AliExpress search terms:** `"SCD40 CO2 sensor module"` + `"ESP32 WROOM development board"`

**Squad use cases:**
- CO2 > 1000 ppm → Teams notification: "CO2 is getting high in your office — open a window for 5 minutes"
- CO2 > 1500 ppm + calendar shows deep work → Squad interrupts with a break suggestion
- Weekly air quality report: trends by time of day
- Trigger ventilation fan (via smart plug) when CO2 spikes

**Safety:** ✅ ESP32 runs on 3.3V USB. Sensor is passive. No mains involved.

---

### Scenario 8: Automated Plant Watering

**Problem:** Plants get forgotten during intense work periods. Overwatering is also common.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Soil moisture sensor | Capacitive soil moisture sensor v2.0 | $2–3 each |
| ESP32 dev board | ESP32-WROOM-32 | $5–8 |
| 5V mini water pump | Submersible mini pump | $3–5 |
| Silicone tubing | 5mm ID tube, 1m | $2 |
| Water reservoir | Any container | $0 |

**Total per plant:** ~$12–18

**Software integration:**
- ESP32 runs ESPHome: reads moisture sensor, controls pump via GPIO relay
- Home Assistant auto-discovers via mDNS
- Squad reads moisture entity, triggers watering or sends reminder

**Squad use cases:**
- Moisture drops below 30% → auto-water for 5 seconds OR send reminder
- Watering log: "Basil was watered 3 times this week (automated)"
- Vacation mode: Ralph increases watering frequency when calendar shows Tamir is traveling
- Over-water prevention: won't water if soil moisture is already above 60%

**Safety:** ✅ 5V DC pump, USB-powered ESP32. Completely low-voltage. Keep electronics elevated above water level.

---

### Scenario 9: Desk Occupancy / Presence Detection

**Problem:** Squad wastes resources running automations when nobody is actually at the desk.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| mmWave presence sensor | LD2410 or HLK-LD2410B | $5–8 |
| ESP32 dev board | ESP32-WROOM-32 | $5–8 |

**AliExpress search terms:** `"LD2410 24GHz human presence sensor"` — detects stationary presence (unlike PIR which needs movement).

**Software integration:**
- ESP32 + ESPHome reads LD2410 UART output
- Exposes `binary_sensor.desk_occupied` in Home Assistant
- Squad checks presence before triggering any physical automation

**Squad use cases:**
- Nobody at desk for 30 min → turn off monitors, reduce lighting to 20%
- Person detected + no calendar meeting → Deep Work mode activates
- Late-night presence detection: it's past midnight and someone's at the desk → send Teams check-in: "Still working? Want me to clear tomorrow morning's calendar?"
- Combine with CO2 + temperature for full "home office health" dashboard

**Safety:** ✅ 3.3V mmWave radar. USB-powered. Non-ionizing radiation far below any safety threshold.

---

### Scenario 10: Printer Automation (Existing HP ePrint Tie-in)

**Problem:** The decisions.md already documents an HP ePrint printer. Squad currently emails files to `dresherhome@hpeprint.com`. But there's no feedback loop — Squad doesn't know if the printer ran out of paper/ink.

**Hardware needed:**
| Item | Example | Price |
|------|---------|-------|
| Smart plug with power monitoring | Gosund SP111 (supports energy monitoring) | $8–10 |

**Software integration:**
- Plug printer into energy-monitoring smart plug
- If power draw drops to idle immediately after a print job starts → paper jam or empty tray
- Squad monitors power curve: printing = 10–15W, idle = 2–3W, paper feed = brief 30W spike

**Squad use cases:**
- Print job sent → no power spike in 60 seconds → Teams notification: "Printer may need attention (paper or ink)"
- Printer left on overnight → auto-off at midnight, auto-on at 7 AM
- Usage log: how many print jobs per week (energy spike count)
- Existing decisions.md family printing flow gets a confirmation loop

**Safety:** ✅ Standard smart plug, no modification to printer.

---

## 3. Top 2 Prototype Recommendations

### Why These Two?

| Criterion | Scenario A: Smart Plugs | Scenario B: Temperature + IR |
|-----------|------------------------|------------------------------|
| **Immediate Squad value** | High — schedule/monitor any device | High — climate automation |
| **Hardware cost** | $6–8 per plug | $35–45 total |
| **Setup time** | 30 minutes | 2–3 hours |
| **No electrical expertise** | ✅ Plug-in only | ✅ USB + plug-in only |
| **Squad integration complexity** | Low (REST API) | Medium (Zigbee stack) |
| **Reversibility** | Fully reversible, unplug anytime | Fully reversible |
| **Risk level** | Zero | Zero |

**Start here:** These two together give Squad full control over power + climate without touching any wiring.

---

## 4. Step-by-Step Implementation Plans

### Prototype A: Smart Plug Squad Integration

#### Hardware Setup (30 minutes)

1. **Buy:** 2× Gosund SP111 or BlitzWolf BW-SHP6 (search AliExpress for `"Gosund SP111 Tuya 16A"`)
2. **Plug in** to wall outlet — LED will flash (setup mode)
3. **Install Smart Life app** on phone (free)
4. **Add device** in app → connect to home WiFi
5. Note the device IDs from the app (or use `tuyapy` to enumerate them)

#### Software Setup (45 minutes)

**Option A: Direct Tuya Cloud API (simplest)**

```bash
# Install tinytuya (Python library for Tuya devices)
pip install tinytuya

# Scan local network for devices (get device keys)
python -m tinytuya scan
```

```python
# squad-tools/smart_plug.py
import tinytuya

def turn_on(device_id: str, ip: str, key: str):
    d = tinytuya.OutletDevice(device_id, ip, key)
    d.set_version(3.3)
    d.turn_on()

def turn_off(device_id: str, ip: str, key: str):
    d = tinytuya.OutletDevice(device_id, ip, key)
    d.set_version(3.3)
    d.turn_off()

def get_status(device_id: str, ip: str, key: str) -> dict:
    d = tinytuya.OutletDevice(device_id, ip, key)
    d.set_version(3.3)
    return d.status()
```

**Option B: Home Assistant (more robust, recommended for multi-device)**

```bash
# Install Home Assistant in Docker (runs on squad machine)
docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ=Asia/Jerusalem \
  -v ha-config:/config \
  -p 8123:8123 \
  ghcr.io/home-assistant/home-assistant:stable
```

Then in HA: Settings → Integrations → Add "Tuya" → follow OAuth flow.

#### Squad MCP Integration

```typescript
// .squad/mcp-servers/iot-mcp/index.ts
// MCP server exposing smart home tools to all agents

const tools = [
  {
    name: "smart_plug_on",
    description: "Turn on a smart plug by name",
    inputSchema: {
      type: "object",
      properties: {
        plug_name: { type: "string", enum: ["office_monitors", "coffee_machine", "desk_fan", "printer"] }
      }
    }
  },
  {
    name: "smart_plug_off", 
    description: "Turn off a smart plug by name",
    inputSchema: { /* same as above */ }
  },
  {
    name: "smart_plug_status",
    description: "Get power status and wattage of a smart plug",
    inputSchema: { /* plug_name */ }
  }
];
```

Add to `.squad/mcp-servers.md`:
```yaml
- name: iot
  command: node
  args: [".squad/mcp-servers/iot-mcp/dist/index.js"]
  description: "Physical world control — smart plugs, sensors, climate"
```

#### Ralph Integration (Automation Rules)

Add to Ralph's watch loop configuration:

```yaml
# .squad/skills/ralph-watch/rules/physical-world.yaml
rules:
  - name: "office-night-off"
    trigger: time(23:00)
    condition: "calendar.no_events_after_now(hours=2)"
    action: smart_plug_off(plug_name="office_monitors")
    notify: false  # silent automation

  - name: "printer-watchdog"
    trigger: event(print_job_sent)
    condition: "smart_plug_status(plug_name='printer').watts < 5 after 90s"
    action: teams_notify("Printer may need attention — no activity detected after print job")

  - name: "morning-coffee"
    trigger: time(07:25)
    condition: "calendar.has_wfh_today()"
    action: smart_plug_on(plug_name="coffee_machine")
    notify: teams("☕ Coffee machine turned on — ready in 5 minutes")
```

---

### Prototype B: Temperature Sensing + IR Climate Control

#### Hardware Setup (1 hour)

1. **Buy:**
   - 1× SONOFF Zigbee 3.0 USB Dongle Plus (search: `"SONOFF Zigbee USB dongle Plus"`)
   - 2× SONOFF SNZB-02 temperature sensors (search: `"SNZB-02 Zigbee temperature"`)
   - 1× BroadLink RM4 Mini (search: `"BroadLink RM4 Mini IR blaster"`)

2. **Plug Zigbee dongle** into squad machine USB port

3. **Place temperature sensors:** one in office, one in living room

4. **Place IR blaster:** aimed at AC unit (line-of-sight, or bounced off wall — IR bounces)

5. **Plug IR blaster into USB power** (any phone charger)

#### Software Setup (2 hours)

**Step 1: Zigbee2MQTT**

```bash
# Install Zigbee2MQTT via Docker
docker run -d \
  --name zigbee2mqtt \
  --restart=unless-stopped \
  -v zigbee2mqtt-data:/app/data \
  --device=/dev/ttyUSB0:/dev/ttyACM0 \
  -p 8080:8080 \
  koenkk/zigbee2mqtt
```

On Windows with the SONOFF dongle:
```powershell
# Find COM port of dongle
Get-WmiObject -Class Win32_SerialPort | Select-Object Name, DeviceID

# Configure Zigbee2MQTT data/configuration.yaml
# serial:
#   port: COM5  (whatever port shows up)
```

**Step 2: Pair temperature sensors**

```yaml
# In Zigbee2MQTT web UI (http://localhost:8080):
# Click "Permit join" → hold button on SNZB-02 for 5 seconds
# Device appears as "0x00158d000xxx" → rename to "office_temp"
```

**Step 3: BroadLink IR learning**

```python
# pip install broadlink
import broadlink

# Discover device on network
devices = broadlink.discover(timeout=5)
device = devices[0]
device.auth()

# Learn IR code (point real remote at blaster, press AC button)
device.enter_learning()
import time; time.sleep(5)
ac_heat_22 = device.check_data()

# Save learned codes
import pickle
with open("ir_codes.pkl", "wb") as f:
    pickle.dump({"ac_heat_22": ac_heat_22, "ac_off": ac_off_code}, f)

# Send command
device.send_data(ac_heat_22)
```

**Step 4: Squad climate agent**

```python
# squad-tools/climate_agent.py
"""
Climate automation agent for Squad.
Called by Ralph when temperature thresholds are breached.
"""
import paho.mqtt.client as mqtt
import broadlink
import json

OFFICE_TEMP_SENSOR = "zigbee2mqtt/office_temp"
COMFORT_MIN = 20.0  # Celsius
COMFORT_MAX = 25.0

def on_message(client, userdata, msg):
    data = json.loads(msg.payload)
    temp = data["temperature"]
    
    if temp < COMFORT_MIN:
        trigger_ac_heat(target=22)
        notify_teams(f"🌡️ Office is {temp}°C — turned on heating to 22°C")
    elif temp > COMFORT_MAX:
        trigger_ac_cool(target=23)
        notify_teams(f"🌡️ Office is {temp}°C — turned on cooling to 23°C")

def trigger_ac_heat(target: int):
    device = get_broadlink_device()
    device.send_data(IR_CODES[f"ac_heat_{target}"])

# Connect to MQTT broker
client = mqtt.Client()
client.on_message = on_message
client.connect("localhost", 1883)
client.subscribe(OFFICE_TEMP_SENSOR)
client.loop_forever()
```

**Step 5: Morning pre-warm automation**

```python
# Called by Ralph at 7:00 AM on work-from-home days
def morning_preheat():
    """
    Squad checks Tamir's calendar for WFH days.
    If WFH detected, pre-heats office 30 minutes before first meeting.
    """
    calendar_events = get_today_calendar()
    first_meeting = min(calendar_events, key=lambda e: e.start)
    preheat_time = first_meeting.start - timedelta(minutes=30)
    
    # Schedule the action
    schedule.at(preheat_time).do(trigger_ac_heat, target=22)
    notify_teams(f"🏠 Pre-heating office for {first_meeting.title} at {first_meeting.start}")
```

---

## 5. Privacy & Security Analysis

### Threat Model

This is a personal home automation setup. The threat model is:
1. **External attacker** gaining control of home devices
2. **Data leakage** of home state/presence information
3. **Physical safety** from automation failures
4. **Privacy** from always-on sensors

### Analysis by Risk Level

#### 🔴 High Risk — Mitigations Required

| Risk | Mitigation |
|------|-----------|
| Tuya cloud API credentials leaked in repo | Store in `.squad/secrets/` (gitignored) or use environment variables. NEVER commit API keys. |
| Home Assistant exposed to internet | **Do not** enable remote access unless using Nabu Casa ($6.50/month with E2E encryption). Keep HA on local network only. |
| Zigbee network spoofing | Use Zigbee3 (not Zigbee1.2) — all SNZB-02 and SONOFF dongles use Zigbee3 with AES-128 encryption by default. |

#### 🟡 Medium Risk — Best Practices

| Risk | Mitigation |
|------|-----------|
| Presence detection data (who's home, when) | Keep all data local. Don't send presence data to cloud services. MQTT broker stays on local machine. |
| Smart plug control by unauthorized party | Set Home Assistant auth tokens with short expiry (24h tokens for Squad, rotated weekly by Ralph). |
| IR blaster replays (AC commands intercepted) | IR is line-of-sight, unencrypted by nature — acceptable for AC/TV control. Don't use IR for locks or security devices. |
| ESP32/ESPHome firmware updates | Pin ESPHome version in config, review changelogs before upgrading. |

#### 🟢 Low Risk — Informational

| Risk | Notes |
|------|-------|
| Temperature/CO2 data privacy | Non-sensitive. Acceptable to log locally. Don't expose via public endpoint. |
| Smart plug energy data | Mildly sensitive (reveals usage patterns). Keep local only. |
| Zigbee radio interference | Zigbee operates at 2.4GHz. Channel selection avoids WiFi overlap — use Zigbee channel 25 (2475 MHz) which is outside most WiFi channels. |

### Security Architecture Decisions

```
✅ DO:
- All device communication stays on local LAN
- MQTT broker runs on localhost, not exposed externally
- Home Assistant behind authentication (long-lived access tokens)
- Secrets in environment variables, never in git
- Squad IoT MCP server only accessible to local agents

❌ DON'T:
- Open ports on router for home automation (no port forwarding)
- Store device keys in decisions.md or any tracked file
- Use cloud MQTT brokers for presence/sensor data
- Control locks, alarms, or access control via Squad (scope boundary)
```

### Scope Boundary: What Squad Should NOT Control

These are **explicitly out of scope** for Squad physical automation:
- Door locks / deadbolts
- Security cameras / alarm systems  
- Any device connected to 230V mains directly (no smart panel, no rewiring)
- Gas appliances
- Medical devices

The philosophy: Squad controls **convenience** devices. Anything with a safety or security implication stays human-controlled.

---

## 6. Cost Breakdown

### Prototype A: Smart Plug Control

| Item | Quantity | Unit Price | Total |
|------|----------|-----------|-------|
| Gosund SP111 smart plug (Tuya, 16A, energy monitoring) | 3 | $7 | $21 |
| Shipping (AliExpress standard) | 1 | $3 | $3 |
| **Total hardware** | | | **$24** |
| Software | — | Free | $0 |
| Time investment | ~2 hours | — | — |
| **All-in cost** | | | **$24** |

**Break-even:** If Squad catches one "heater left on all day" incident per month (saves ~4 kWh/day × 30 days × $0.10/kWh = $12/month), payback in 2 months.

---

### Prototype B: Temperature + IR Climate Control

| Item | Quantity | Unit Price | Total |
|------|----------|-----------|-------|
| SONOFF Zigbee 3.0 USB Dongle Plus | 1 | $14 | $14 |
| SONOFF SNZB-02 temperature/humidity sensor | 2 | $9 | $18 |
| BroadLink RM4 Mini IR blaster | 1 | $18 | $18 |
| Shipping (AliExpress standard) | 1 | $4 | $4 |
| **Total hardware** | | | **$54** |
| Software | — | Free | $0 |
| Time investment | ~3 hours | — | — |
| **All-in cost** | | | **$54** |

**Value calculation:**
- Heating/cooling 30 minutes early (inefficient) wastes ~0.5 kWh/day
- Smart scheduling saves $0.05/day × 200 working days = $10/year in energy
- Real value: comfort (pre-warmed office) and cognitive load reduction

---

### Combined System (Both Prototypes)

| Item | Cost |
|------|------|
| Prototype A (smart plugs ×3) | $24 |
| Prototype B (Zigbee + IR) | $54 |
| Optional: Raspberry Pi Zero 2W (run HA separately from squad machine) | $18 |
| Optional: micro SD card 32GB | $4 |
| **Full system total** | **$78–100** |

**Comparison:** A commercial solution (Philips Hue + Nest + SmartThings) would cost $300–500 for equivalent functionality, with worse Squad integration.

---

## 7. Rejected Approaches

### Why Not Z-Wave?
Z-Wave devices are $30–80 each (vs $7–15 for Zigbee). Requires a separate Z-Wave USB dongle. No price advantage for our budget constraint. Zigbee wins.

### Why Not Matter/Thread?
Matter is the new standard but device ecosystem is still sparse on AliExpress (2026). Prices are 2–3× higher. Give it 2 more years. 

### Why Not Voice Assistants (Alexa/Google Home)?
Privacy concern: constant microphone. Squad is text-based (Teams/WhatsApp/GitHub). Voice adds complexity with no benefit for our use case. Squad talks through Teams, not speakers.

### Why Not Commercial Systems (SmartThings, Home Assistant Yellow)?
Hub hardware costs $80–150. Squad already runs on a capable Windows machine. Running Home Assistant in Docker on the squad machine is free and more integrated.

### Why Not Raspberry Pi as Primary Device?
The squad machine is already running 24/7. Adding another always-on device increases electricity cost (~3W × 8760h × $0.10/kWh = $2.6/year — negligible, but unnecessary complexity).

---

## 8. Future Roadmap

Once Prototypes A and B are stable (estimated: 2–4 weeks of real-world use), these are the natural next steps:

### Phase 2 (Month 2): Environmental Intelligence
- Add CO2 sensor (Scenario 7) — single biggest impact on productivity
- Add presence detection (Scenario 9) — enables fully automatic idle detection
- Build "Home Office Health Dashboard" in Teams: daily digest with temperature, CO2, device uptime

### Phase 3 (Month 3): Full Scene Automation
- Add smart LED bulbs (Scenario 4) — lighting modes based on calendar context
- Add door sensor (Scenario 5) — reliable "home/away" detection
- Implement smart button (Scenario 6) — physical Squad trigger on desk

### Phase 4 (Month 4+): Squad Physical Agent
- Create dedicated `physical` Squad agent: owns all IoT MCP tools
- Integrates with existing decisions.md family rules (printer feedback loop from Scenario 10)
- Speaks to Tamir through Teams: "Your office pre-heated for the standup in 20 minutes. CO2 is fine. Coffee machine is on."
- Becomes the "home concierge" agent — same pattern as Ralph for digital monitoring

### Metrics to Track
- Energy savings per month (from smart plugs with power monitoring)
- Number of "comfort interventions" (auto-adjustments that avoided manual action)
- Temperature consistency score (how often office was in 20–24°C range)
- Squad physical action count per week (automation volume growth)

---

## Appendix: AliExpress Shopping List

Quick-reference for the recommended hardware:

| Item | Search Term | Target Price |
|------|------------|-------------|
| Smart plug (energy monitoring) | `Gosund SP111 Tuya WiFi 16A energy` | $6–8 |
| Zigbee USB coordinator | `SONOFF Zigbee 3.0 USB Dongle Plus` | $12–15 |
| Zigbee temp sensor | `SNZB-02 Zigbee temperature humidity` | $8–10 |
| IR blaster | `BroadLink RM4 Mini WiFi IR` | $15–18 |
| Smart button | `Aqara WXKG11LM Zigbee mini switch` | $8–10 |
| Door sensor | `SNZB-04 Zigbee door window sensor` | $7–9 |
| LED bulb Zigbee | `Tuya Zigbee E27 RGBW 9W bulb` | $8–12 |
| CO2 sensor module | `SCD40 CO2 sensor I2C` | $20–25 |
| ESP32 dev board | `ESP32-WROOM-32 development board` | $4–6 |
| mmWave presence | `LD2410 24GHz human presence sensor` | $5–7 |

**Pro tip:** Search AliExpress with "Zigbee" + device type for the best price-to-quality ratio. Avoid no-brand WiFi devices without Tuya/Smart Life branding — they often use locked firmware that can't be integrated.

---

## Appendix: Software Stack Reference

| Software | Purpose | License | Runs on |
|----------|---------|---------|---------|
| Home Assistant | IoT hub & automation | Apache 2.0 | Docker / RPi |
| Zigbee2MQTT | Zigbee coordinator bridge | GPL-3.0 | Docker / Node |
| Mosquitto | MQTT broker | EPL-2.0 | Docker |
| ESPHome | ESP32/ESP8266 firmware | MIT | ESP32 (flashed) |
| tinytuya | Tuya device Python library | MIT | Squad machine |
| broadlink | BroadLink IR Python library | MIT | Squad machine |
| paho-mqtt | MQTT Python client | EPL-1.0 | Squad machine |

All free and open-source. No subscriptions required (except optionally Nabu Casa for remote HA access at $6.50/month — not needed for local-only Squad integration).

---

*Document written by Seven (Research & Docs agent) for GitHub Issue #1203*  
*Next step: Picard to review architecture decisions, Belanna to review Docker/infrastructure setup*

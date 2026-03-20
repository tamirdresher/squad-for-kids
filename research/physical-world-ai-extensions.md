# Physical World AI Extensions: Scenarios & Prototypes

**Issue:** #1203  
**Author:** B'Elanna Torres (Infrastructure Expert)  
**Date:** 2026-03-20  
**Status:** Research Complete

## Executive Summary

This document explores extending the AI Squad architecture from pure software orchestration into the physical world through low-cost, achievable home automation scenarios. The focus is on bridging AI agent capabilities with real-world device control while respecting budget constraints (~AliExpress pricing) and limited electrical expertise.

**Key Finding:** The Squad's existing multi-agent orchestration patterns translate directly to smart home automation. The same principles of decentralized decision-making, event-driven coordination, and specialized agents apply to physical device control.

---

## 1. Physical World Scenarios

### 1.1 Home Automation Use Cases

| Scenario | Description | AI Agent Role | Physical Component |
|----------|-------------|---------------|-------------------|
| **Adaptive Lighting** | Adjust lighting based on time of day, presence, activity | Monitor presence sensors, control smart bulbs | Zigbee/WiFi bulbs, motion sensors |
| **Climate Optimization** | HVAC control based on occupancy, weather forecast, energy rates | Forecast-driven scheduling, occupancy detection | Smart thermostat, temp sensors |
| **Security Monitoring** | Motion/door sensors with intelligent alerting | Event correlation, false positive filtering, alert routing | Door sensors, cameras, motion detectors |
| **Voice-Controlled Tasks** | Natural language control of devices via Teams/Alexa | NLP parsing, device mapping, execution | Voice hub integration |
| **Energy Management** | Track/reduce consumption, shift load to off-peak | Usage analytics, predictive scheduling | Smart plugs, energy monitors |
| **Presence Simulation** | Randomized device activation when away | Behavioral modeling, schedule generation | Smart switches, bulbs |

### 1.2 Integration with Squad Architecture

**Agent Specialization Applied to Physical World:**
- **Ralph (Monitor)** → Device state monitoring, sensor event polling
- **Kes (Communication)** → Voice interface, alert routing, status reporting
- **Worf (Security)** → Access control rules, anomaly detection, security alerts
- **Data (Code Expert)** → Integration code, API adapters, automation scripts
- **Belanna (Infrastructure)** → Network setup, device provisioning, reliability

**Example Flow — Adaptive Lighting:**
1. Ralph monitors occupancy sensors (motion detectors)
2. Data evaluates time-of-day + room activity context
3. Belanna executes lighting scene (warm evening, bright work mode)
4. Kes notifies via Teams if manual override needed

---

## 2. Smart Home Integration Patterns

### 2.1 Technology Stack Options

| Technology | Protocol | Cost | Complexity | Hub Required | Pros | Cons |
|------------|----------|------|------------|--------------|------|------|
| **Zigbee** | IEEE 802.15.4 | $ | Low | Yes | Low power, mesh network, vendor-agnostic | Requires hub |
| **WiFi Devices** | WiFi | $ | Low | No | Direct integration, simple setup | Power hungry, congestion |
| **Z-Wave** | Z-Wave | $$ | Medium | Yes | Reliable mesh, security | More expensive, proprietary |
| **Matter** | Multi-protocol | $$ | Medium | Varies | Future-proof, interop standard | Ecosystem still maturing |
| **MQTT Devices** | WiFi+MQTT | $ | Medium | No | Open standard, flexible | DIY assembly required |

**Recommendation:** Start with **WiFi + Zigbee hybrid**
- WiFi for high-bandwidth devices (cameras, voice hubs)
- Zigbee for sensors and switches (low-power mesh)
- Hub: Home Assistant or Zigbee2MQTT on Raspberry Pi

### 2.2 Architecture Patterns

#### Pattern A: Centralized Hub + API Gateway
```
[AI Squad] <--REST/MQTT--> [Home Assistant] <--Zigbee/WiFi--> [Devices]
```
- **Pros:** Single integration point, existing device library
- **Cons:** Hub reliability becomes SPOF
- **Best For:** Heterogeneous device ecosystem

#### Pattern B: Direct Device Control
```
[AI Squad] <--API/MQTT--> [Smart Devices]
```
- **Pros:** No hub dependency, lower latency
- **Cons:** Per-device integration work
- **Best For:** Small deployments, homogeneous devices

#### Pattern C: Event-Driven via MQTT
```
[AI Squad] <--> [MQTT Broker] <--> [Devices + Home Assistant]
```
- **Pros:** Decoupled, scalable, async
- **Cons:** More complex setup
- **Best For:** Large deployments, real-time coordination

**Recommended:** Start with Pattern A, evolve to Pattern C as needed

---

## 3. Voice/Teams Interface Design

### 3.1 Voice Command Architecture

**Microsoft Teams Integration:**
- Use existing Kes (Communication agent) as voice command router
- Teams bot receives voice input via speech-to-text
- Parse intent → map to device action → execute

**Command Flow:**
```
User (Teams Voice) → Speech-to-Text → Kes Bot
  → Intent Parser (NLU)
    → Device Mapper (resolve "living room lights" → entity_id)
      → Execution (REST/MQTT to hub)
        → Confirmation (TTS response)
```

**Example Commands:**
- "Turn off all lights" → `light.turn_off` for all light entities
- "Set thermostat to 22 degrees" → `climate.set_temperature` with value 22
- "Is the front door locked?" → Query `lock.front_door` state
- "Good night" → Trigger scene (lights off, doors locked, alarm on)

### 3.2 Status Reporting

**Teams Adaptive Card Example:**
```json
{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "text": "🏠 Home Status",
      "weight": "bolder",
      "size": "large"
    },
    {
      "type": "FactSet",
      "facts": [
        {"title": "Temperature", "value": "21°C"},
        {"title": "Living Room", "value": "💡 Occupied"},
        {"title": "Front Door", "value": "🔒 Locked"},
        {"title": "Energy Today", "value": "12.4 kWh"}
      ]
    }
  ]
}
```

---

## 4. Privacy and Security Considerations

### 4.1 Threat Model

| Threat | Impact | Likelihood | Mitigation |
|--------|--------|------------|------------|
| **Unauthorized Access** | Device control, surveillance | Medium | Network isolation, auth tokens |
| **Data Exfiltration** | Privacy breach (camera feeds) | Low | Local processing, encrypted storage |
| **Command Injection** | Malicious device control | Medium | Input validation, command whitelisting |
| **Hub Compromise** | Full system control | High Impact | Isolated VLAN, firewall rules |
| **Vendor Cloud Breach** | Depends on device | Low | Prefer local-only devices |

### 4.2 Security Architecture

**Network Segmentation:**
```
[Internet] <-- Firewall --> [Main Network] (Squad servers)
                  |
                  v
            [IoT VLAN] (Smart devices)
              - No internet access for sensors
              - Limited ingress from Squad subnet
              - No device-to-device communication
```

**Access Control:**
- Home Assistant: Long-lived access tokens (rotate monthly)
- MQTT: Username/password auth + TLS
- API endpoints: IP whitelist (Squad server IPs only)
- Voice commands: User identity verification via Teams

---

## 5. Feasibility Matrix

### 5.1 Prototype Candidate Ranking

| Scenario | Cost | Complexity | Impact | Time to MVP | Feasibility Score |
|----------|------|------------|--------|-------------|-------------------|
| **Smart Lighting Control** | $50 | Low | High | 2 days | ⭐⭐⭐⭐⭐ |
| **Temperature Monitoring** | $30 | Low | Medium | 1 day | ⭐⭐⭐⭐⭐ |
| **Motion Detection Alerts** | $40 | Low | Medium | 2 days | ⭐⭐⭐⭐ |
| **Voice-Controlled Scenes** | $60 | Medium | High | 4 days | ⭐⭐⭐⭐ |
| **Door/Window Sensors** | $45 | Low | Medium | 2 days | ⭐⭐⭐⭐ |
| **Smart Thermostat** | $120 | Medium | High | 5 days | ⭐⭐⭐ |
| **Energy Monitoring** | $35 | Medium | Low | 3 days | ⭐⭐⭐ |
| **Security Camera** | $40 | High | Medium | 7 days | ⭐⭐ |

**Cost Breakdown (MVP Kit):**
- Raspberry Pi 4 (4GB) + Case: $75 (hub)
- Zigbee USB Stick (Sonoff 3.0): $25
- WiFi Smart Bulbs (4x): $40 (Tuya/Tasmota)
- Zigbee Motion Sensors (2x): $30
- Zigbee Temp Sensors (2x): $20
- Door/Window Sensors (4x): $35
- Smart Plug (energy monitor): $15
- **Total: $240** (AliExpress pricing)

---

## 6. Prototype Specifications

### 6.1 Prototype #1: Smart Lighting with Presence Detection

**Objective:** Auto-adjust lighting based on room occupancy and time of day

**Hardware:**
- 2x Tuya WiFi Smart Bulbs (~$10 each)
- 1x Zigbee Motion Sensor (~$15)
- 1x Raspberry Pi 4 with Zigbee stick (~$100)

**Software Stack:**
- Home Assistant OS on Raspberry Pi
- Zigbee2MQTT for motion sensor
- Node.js script for Squad integration

**Success Criteria:**
- ✅ Motion detection triggers light activation within 500ms
- ✅ Brightness adjusts based on time of day
- ✅ Squad agent logs events to monitoring dashboard
- ✅ Teams notification on first activation each day

**Cost:** ~$135

### 6.2 Prototype #2: Temperature Monitoring with HVAC Recommendation

**Objective:** Monitor home temperature and provide HVAC optimization suggestions

**Hardware:**
- 2x Zigbee Temperature/Humidity Sensors (~$10 each)
- Same Raspberry Pi hub from Prototype #1

**Software:**
- Home Assistant for data collection
- Node.js script for analytics
- Teams bot for recommendations

**Success Criteria:**
- ✅ Temperature data collected every 5 minutes
- ✅ Alerts sent when temp out of comfort range
- ✅ Daily summary with energy-saving tips
- ✅ Historical data visualization (7 days)

**Cost:** ~$20 (incremental)

---

## 7. Scalability Roadmap

### Phase 1: MVP (2-4 weeks)
- [x] Research completed
- [ ] Implement Prototype #1 (Smart Lighting)
- [ ] Implement Prototype #2 (Temperature Monitoring)
- [ ] Basic Teams voice commands
- [ ] Security baseline (network isolation, access tokens)

### Phase 2: Expansion (1-2 months)
- [ ] Add door/window sensors
- [ ] Energy monitoring with smart plugs
- [ ] Advanced scenes (morning routine, bedtime, away mode)
- [ ] Weather integration for predictive HVAC
- [ ] Mobile dashboard (Teams + web UI)

### Phase 3: Intelligence (2-3 months)
- [ ] Machine learning for occupancy patterns
- [ ] Anomaly detection (unusual energy use, unexpected motion)
- [ ] Predictive maintenance (device offline detection)
- [ ] Voice command NLU improvements
- [ ] Integration with calendar (meeting mode lighting)

### Phase 4: Advanced Automation (3-6 months)
- [ ] Cross-room coordination (lights follow movement)
- [ ] Energy arbitrage (shift load to off-peak hours)
- [ ] Multi-home management (vacation property)
- [ ] Smart irrigation (soil sensors + weather API)
- [ ] Vehicle integration (garage door + car presence)

---

## 8. Next Steps

### Immediate (This Week)
1. ✅ Complete research document
2. [ ] Order MVP hardware kit ($240 from AliExpress)
3. [ ] Set up Home Assistant on Raspberry Pi
4. [ ] Configure network isolation (IoT VLAN)

### Short-Term (Next 2 Weeks)
1. [ ] Build Prototype #1 (Smart Lighting)
2. [ ] Build Prototype #2 (Temperature Monitoring)
3. [ ] Create Teams bot integration
4. [ ] Write integration documentation

---

## 9. Recommended Vendors (AliExpress)

**Budget-Friendly Options:**
- **Zigbee Hub:** Sonoff ZBBridge ($20) or Zigbee USB Stick ($15)
- **Smart Bulbs:** Tuya/SmartLife WiFi bulbs ($8-12 each)
- **Motion Sensors:** Aqara Zigbee ($12-15)
- **Temp/Humidity:** Xiaomi Mi Temp Sensor 2 ($8-10)
- **Door Sensors:** Aqara Door/Window Sensor ($10-12)
- **Smart Plugs:** Nous A1 Tasmota (energy monitor, $12-15)

---

## Conclusion

Extending the AI Squad into the physical world via home automation is both technically feasible and cost-effective. The proposed MVP (smart lighting + temperature monitoring) can be implemented for ~$155 in hardware and 3-4 days of development time.

**Key Success Factors:**
1. Start simple: Two prototypes before expanding
2. Leverage existing tools: Home Assistant, MQTT, Teams
3. Security first: Network isolation, access control, audit logging
4. User consent: Explicit opt-in, manual overrides
5. Iterative approach: Build, test, learn, expand

The Squad's multi-agent architecture naturally extends to physical device orchestration. The same patterns of event-driven coordination, specialized agents, and centralized monitoring apply.

**Recommendation:** Proceed with prototype development. Order hardware immediately to begin hands-on validation of integration patterns.

---

**Document Status:** ✅ Research Complete  
**Next Owner:** Data (for prototype implementation) + Worf (security review)  
**Estimated Implementation Time:** 1-2 weeks for both prototypes

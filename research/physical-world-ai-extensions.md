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

### 2.3 Device Communication Standards

**Home Assistant REST API:**
```http
POST /api/services/light/turn_on
Authorization: Bearer <token>
{
  "entity_id": "light.living_room",
  "brightness": 200,
  "color_temp": 370
}
```

**MQTT Topic Structure:**
```
homeassistant/light/living_room/set
{"state": "ON", "brightness": 200}

zigbee2mqtt/living_room_motion/occupancy
{"occupancy": true}
```

**Integration Example (Node.js):**
```javascript
const mqtt = require('mqtt');
const client = mqtt.connect('mqtt://homeassistant.local');

client.subscribe('zigbee2mqtt/+/occupancy');
client.on('message', (topic, message) => {
  const payload = JSON.parse(message);
  if (payload.occupancy) {
    // Trigger Squad agent workflow
    notifySquad({ room: topic.split('/')[1], occupied: true });
  }
});
```

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

**Natural Language Patterns:**
```json
{
  "command": "turn on living room lights",
  "intent": "device_control",
  "action": "turn_on",
  "device_type": "light",
  "location": "living_room"
}
```

### 3.2 Alexa/Google Home Integration

**Option 1: Direct Skill (Complex)**
- Build Alexa Skill or Google Action
- Host fulfillment endpoint
- Handle OAuth for device control

**Option 2: Home Assistant Cloud (Simple)**
- Enable Home Assistant Cloud ($5/mo)
- Alexa/Google Assistant pre-integrated
- Devices auto-discovered

**Option 3: Teams as Voice Proxy (Hybrid)**
- User speaks to Alexa/Google Home
- Webhook triggers Teams bot
- Bot routes through Squad agents
- Best for custom automation logic

**Recommended:** Start with Option 3 for maximum flexibility

### 3.3 Status Reporting

**Proactive Notifications:**
- Motion detected when alarm armed → Teams alert
- Temperature out of range → HVAC adjustment + notification
- Device offline → Diagnostic check + user alert

**On-Demand Status:**
- "What's the status?" → Summary of all devices
- "Show camera feed" → Adaptive card with snapshot
- "Energy usage today?" → Chart/stats card

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

**Data Handling:**
- **Camera Feeds:** Local storage only, 7-day retention, no cloud upload
- **Sensor Data:** Anonymized aggregation, no PII
- **Voice Commands:** Processed locally, logs scrubbed of names
- **Device States:** Encrypted at rest if DB used

### 4.3 Privacy Best Practices

**Data Minimization:**
- Only collect sensor data necessary for automation
- No video recording unless motion detected + alarm armed
- Delete logs after 30 days

**User Consent:**
- Explicit opt-in for voice recording
- Clear indication when monitoring active (LED indicators)
- Manual disable switches for cameras/mics

**Compliance Considerations:**
- GDPR: User right to erasure (purge device data)
- CCPA: Disclosure of data collection practices
- Local Laws: Check recording consent laws (single vs. two-party)

**Audit Trail:**
- Log all device control actions with timestamp + actor
- Retain security events (unauthorized access attempts) for 90 days
- Monthly review of access patterns

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

### 5.2 Constraints Analysis

**Budget (~AliExpress):**
- ✅ Most devices $10-30 each
- ✅ Hub under $100 (RPi or used mini PC)
- ⚠️ Camera quality suffers below $50
- ⚠️ Smart thermostats expensive ($120+)

**No Electrical Expertise:**
- ✅ Zigbee/WiFi devices are plug-and-play
- ✅ Battery-powered sensors (no wiring)
- ⚠️ Smart switches require neutral wire (check availability)
- ⚠️ Hardwired devices (thermostats, doorbell) need electrician

**Technical Skill:**
- ✅ Squad has software expertise
- ✅ Home Assistant well-documented
- ✅ MQTT/REST APIs straightforward
- ⚠️ Zigbee pairing can be finicky
- ⚠️ Network troubleshooting if WiFi flaky

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

**Implementation Steps:**
1. Install Home Assistant OS on Raspberry Pi
2. Configure Zigbee2MQTT with USB stick
3. Pair motion sensor and bulbs
4. Create REST API integration script:
   ```javascript
   // squad-lighting-agent.js
   const axios = require('axios');
   const mqtt = require('mqtt');
   
   const HA_URL = 'http://homeassistant.local:8123';
   const HA_TOKEN = process.env.HA_TOKEN;
   const mqtt_client = mqtt.connect('mqtt://homeassistant.local');
   
   mqtt_client.subscribe('zigbee2mqtt/motion_sensor_1/occupancy');
   
   mqtt_client.on('message', async (topic, message) => {
     const data = JSON.parse(message);
     if (data.occupancy) {
       const hour = new Date().getHours();
       const brightness = hour < 8 || hour > 20 ? 100 : 255;
       
       await axios.post(`${HA_URL}/api/services/light/turn_on`, {
         entity_id: 'light.living_room',
         brightness: brightness
       }, {
         headers: { 'Authorization': `Bearer ${HA_TOKEN}` }
       });
     }
   });
   ```
5. Deploy as systemd service on Squad server
6. Test with Teams webhook triggers

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

**Implementation:**
1. Pair temperature sensors in key rooms
2. Create data collection service:
   ```javascript
   // squad-climate-agent.js
   const mqtt = require('mqtt');
   const client = mqtt.connect('mqtt://homeassistant.local');
   
   const readings = {};
   
   client.subscribe('zigbee2mqtt/+/temperature');
   client.on('message', (topic, message) => {
     const room = topic.split('/')[1];
     const data = JSON.parse(message);
     readings[room] = {
       temp: data.temperature,
       humidity: data.humidity,
       timestamp: Date.now()
     };
     
     analyzeClimate();
   });
   
   function analyzeClimate() {
     const avgTemp = Object.values(readings)
       .reduce((sum, r) => sum + r.temp, 0) / Object.keys(readings).length;
     
     if (avgTemp > 24) {
       sendTeamsAlert('🌡️ Temperature high: ' + avgTemp.toFixed(1) + '°C. Consider cooling.');
     } else if (avgTemp < 18) {
       sendTeamsAlert('❄️ Temperature low: ' + avgTemp.toFixed(1) + '°C. Consider heating.');
     }
   }
   ```
3. Add weather API integration for forecast-based suggestions
4. Create Teams adaptive card for status dashboard

**Success Criteria:**
- ✅ Temperature data collected every 5 minutes
- ✅ Alerts sent when temp out of comfort range
- ✅ Daily summary with energy-saving tips
- ✅ Historical data visualization (7 days)

**Cost:** ~$20 (incremental)

---

## 7. Integration Code Examples

### 7.1 Home Assistant REST Client

```typescript
// squad-ha-client.ts
import axios, { AxiosInstance } from 'axios';

export class HomeAssistantClient {
  private client: AxiosInstance;
  
  constructor(baseURL: string, token: string) {
    this.client = axios.create({
      baseURL,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
  }
  
  async getState(entityId: string) {
    const response = await this.client.get(`/api/states/${entityId}`);
    return response.data;
  }
  
  async callService(domain: string, service: string, data: any) {
    const response = await this.client.post(
      `/api/services/${domain}/${service}`,
      data
    );
    return response.data;
  }
  
  async turnOnLight(entityId: string, brightness?: number, colorTemp?: number) {
    return this.callService('light', 'turn_on', {
      entity_id: entityId,
      ...(brightness && { brightness }),
      ...(colorTemp && { color_temp: colorTemp })
    });
  }
  
  async setThermostat(entityId: string, temperature: number) {
    return this.callService('climate', 'set_temperature', {
      entity_id: entityId,
      temperature
    });
  }
}

// Usage
const ha = new HomeAssistantClient(
  'http://homeassistant.local:8123',
  process.env.HA_TOKEN!
);

await ha.turnOnLight('light.living_room', 200, 370);
```

### 7.2 MQTT Event Subscriber

```typescript
// squad-mqtt-bridge.ts
import mqtt from 'mqtt';

export class MQTTBridge {
  private client: mqtt.MqttClient;
  private handlers: Map<string, (payload: any) => void> = new Map();
  
  constructor(brokerUrl: string) {
    this.client = mqtt.connect(brokerUrl);
    
    this.client.on('connect', () => {
      console.log('Connected to MQTT broker');
    });
    
    this.client.on('message', (topic, message) => {
      const payload = JSON.parse(message.toString());
      this.handlers.forEach((handler, pattern) => {
        if (this.matchTopic(topic, pattern)) {
          handler(payload);
        }
      });
    });
  }
  
  subscribe(topicPattern: string, handler: (payload: any) => void) {
    this.handlers.set(topicPattern, handler);
    this.client.subscribe(this.wildcardPattern(topicPattern));
  }
  
  publish(topic: string, payload: any) {
    this.client.publish(topic, JSON.stringify(payload));
  }
  
  private matchTopic(topic: string, pattern: string): boolean {
    const regex = new RegExp(
      '^' + pattern.replace(/\+/g, '[^/]+').replace(/#/g, '.*') + '$'
    );
    return regex.test(topic);
  }
  
  private wildcardPattern(pattern: string): string {
    return pattern; // MQTT broker handles +/# wildcards
  }
}

// Usage
const bridge = new MQTTBridge('mqtt://homeassistant.local');

bridge.subscribe('zigbee2mqtt/+/occupancy', (payload) => {
  if (payload.occupancy) {
    console.log('Motion detected!');
    // Trigger Squad workflow
  }
});

bridge.subscribe('homeassistant/climate/+/state', (payload) => {
  console.log(`Thermostat: ${payload.current_temperature}°C`);
});
```

### 7.3 Teams Voice Command Handler

```typescript
// squad-voice-handler.ts
import { TeamsActivityHandler, TurnContext } from 'botbuilder';

export class VoiceCommandHandler extends TeamsActivityHandler {
  constructor() {
    super();
    
    this.onMessage(async (context, next) => {
      const text = context.activity.text?.toLowerCase() || '';
      
      // Parse intent
      const intent = this.parseIntent(text);
      
      switch (intent.type) {
        case 'light_control':
          await this.handleLightControl(context, intent);
          break;
        case 'climate_control':
          await this.handleClimateControl(context, intent);
          break;
        case 'status_query':
          await this.handleStatusQuery(context, intent);
          break;
        default:
          await context.sendActivity('I didn\'t understand that command.');
      }
      
      await next();
    });
  }
  
  private parseIntent(text: string): any {
    if (text.includes('light') || text.includes('lights')) {
      return {
        type: 'light_control',
        action: text.includes('on') ? 'turn_on' : 'turn_off',
        location: this.extractLocation(text)
      };
    }
    
    if (text.includes('temperature') || text.includes('thermostat')) {
      return {
        type: 'climate_control',
        temperature: this.extractNumber(text)
      };
    }
    
    if (text.includes('status') || text.includes('how is')) {
      return { type: 'status_query' };
    }
    
    return { type: 'unknown' };
  }
  
  private async handleLightControl(context: TurnContext, intent: any) {
    // Call Home Assistant API
    const location = intent.location || 'all';
    const action = intent.action;
    
    // Execute
    await ha.callService('light', action, {
      entity_id: `light.${location}`
    });
    
    await context.sendActivity(`✅ Lights ${action === 'turn_on' ? 'on' : 'off'} in ${location}`);
  }
  
  private extractLocation(text: string): string {
    const locations = ['living room', 'bedroom', 'kitchen', 'bathroom'];
    for (const loc of locations) {
      if (text.includes(loc)) {
        return loc.replace(' ', '_');
      }
    }
    return 'all';
  }
  
  private extractNumber(text: string): number | null {
    const match = text.match(/\d+/);
    return match ? parseInt(match[0]) : null;
  }
}
```

---

## 8. Scalability Roadmap

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

## 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Device Compatibility** | Devices don't work with Home Assistant | Research compatibility before purchase, prefer Zigbee (standardized) |
| **WiFi Reliability** | Smart devices offline due to network issues | Use Zigbee mesh for critical devices, WiFi mesh upgrade if needed |
| **Hub Failure** | All automation stops | Raspberry Pi SD card backup, fallback manual control |
| **Security Breach** | Unauthorized device control | Network segmentation, strong auth, regular audits |
| **Privacy Concerns** | Family discomfort with monitoring | Explicit consent, visual indicators, manual disable switches |
| **Cost Overruns** | Exceeds AliExpress budget | Phased rollout, prioritize high-impact low-cost devices |
| **Complexity Creep** | Over-engineered solution | Start simple, add features based on actual usage |

---

## 10. Next Steps

### Immediate (This Week)
1. ✅ Complete research document
2. [ ] Order MVP hardware kit ($240)
   - Raspberry Pi 4 (4GB) + case + power supply
   - Sonoff Zigbee 3.0 USB stick
   - 2x Tuya WiFi smart bulbs
   - 1x Zigbee motion sensor
   - 2x Zigbee temp/humidity sensors
3. [ ] Set up Home Assistant on Raspberry Pi
4. [ ] Configure network isolation (IoT VLAN)

### Short-Term (Next 2 Weeks)
1. [ ] Build Prototype #1 (Smart Lighting)
2. [ ] Build Prototype #2 (Temperature Monitoring)
3. [ ] Create Teams bot integration
4. [ ] Write integration documentation

### Medium-Term (Next Month)
1. [ ] Add voice command support
2. [ ] Expand to additional rooms
3. [ ] Implement security features (door sensors)
4. [ ] Performance monitoring dashboard

### Long-Term (Next Quarter)
1. [ ] Machine learning for pattern recognition
2. [ ] Energy optimization automation
3. [ ] Multi-home support if applicable
4. [ ] Publish case study blog post

---

## 11. Recommended Vendors (AliExpress)

### Budget-Friendly Options
- **Zigbee Hub:** Sonoff ZBBridge ($20) or Zigbee USB Stick ($15)
- **Smart Bulbs:** Tuya/SmartLife WiFi bulbs ($8-12 each)
- **Motion Sensors:** Aqara Zigbee ($12-15)
- **Temp/Humidity:** Xiaomi Mi Temp Sensor 2 ($8-10)
- **Door Sensors:** Aqara Door/Window Sensor ($10-12)
- **Smart Plugs:** Nous A1 Tasmota (energy monitor, $12-15)

### Quality Upgrades (Still Budget)
- **Bulbs:** Philips Hue clones (Gledopto Zigbee, $15)
- **Sensors:** Sonoff Zigbee sensors ($10-18)
- **Hub:** Raspberry Pi 4 + Zigbee stick (total control, $100)

### Avoid
- No-name brands without reviews
- Devices requiring cloud subscription
- Proprietary protocols (vendor lock-in)
- Cheap cameras (security risk + poor quality)

---

## 12. References

### Documentation
- Home Assistant: https://www.home-assistant.io/docs/
- Zigbee2MQTT: https://www.zigbee2mqtt.io/
- MQTT Protocol: https://mqtt.org/mqtt-specification/
- Matter Standard: https://csa-iot.org/all-solutions/matter/

### Example Projects
- Home Automation with Home Assistant (GitHub)
- Zigbee2MQTT Device Compatibility
- DIY Smart Home on a Budget (Reddit r/homeassistant)

### Security Best Practices
- OWASP IoT Top 10
- NIST Cybersecurity for IoT
- Home Network Segmentation Guide

---

## Conclusion

Extending the AI Squad into the physical world via home automation is both technically feasible and cost-effective. The proposed MVP (smart lighting + temperature monitoring) can be implemented for ~$155 in hardware and 3-4 days of development time.

**Key Success Factors:**
1. Start simple: Two prototypes before expanding
2. Leverage existing tools: Home Assistant, MQTT, Teams
3. Security first: Network isolation, access control, audit logging
4. User consent: Explicit opt-in, manual overrides
5. Iterative approach: Build, test, learn, expand

The Squad's multi-agent architecture naturally extends to physical device orchestration. The same patterns of event-driven coordination, specialized agents, and centralized monitoring apply. This research provides a solid foundation for Phase 1 implementation.

**Recommendation:** Proceed with prototype development. Order hardware immediately to begin hands-on validation of integration patterns.

---

**Document Status:** ✅ Research Complete  
**Next Owner:** Data (for prototype implementation) + Worf (security review)  
**Estimated Implementation Time:** 1-2 weeks for both prototypes

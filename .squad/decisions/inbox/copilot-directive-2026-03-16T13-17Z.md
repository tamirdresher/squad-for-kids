### 2026-03-16T13:17Z: Contribution routing policy
**By:** Tamir Dresher (via Copilot)
**What:** Upstream contributions must be classified:
- **Squad core** (bradygaster/squad fork): Only fundamental capabilities that every squad needs (ceremonies, scheduling, directive capture, multi-machine via RFC)
- **Skills repo** (tamirdresher/squad-skills): Provider-specific patterns, agent role templates, specialized plugins (notification routing, Neelix, birthday system)
- **Defer**: Usage templates that are too Copilot CLI-specific or too niche (session recovery, upstream monitor)
**Why:** User request — don't pollute Squad core with specialized patterns. Skills repo is the adapter layer.

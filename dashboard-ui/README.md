# FedRAMP Dashboard UI

React-based UI for the FedRAMP Security Dashboard (Phase 3).

## Features

- **Overview Page**: Real-time compliance status across all environments
- **Control Detail**: Drill-down view for specific FedRAMP controls
- **Environment View**: Per-environment compliance summaries
- **Trend Analysis**: Historical trends and drift detection
- **Live Activity** *(NEW)*: Real-time monitoring of Ralph's orchestration rounds with agent status, tasks, and event stream

## Technology Stack

- **React 18** with TypeScript
- **Material-UI (MUI)** for components
- **Recharts** for data visualization
- **React Router** for navigation
- **Axios** for API communication
- **Vite** for build and development

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
cd dashboard-ui
npm install
```

### Development

```bash
npm run dev
```

Access the dashboard at `http://localhost:3000`

### Build

```bash
npm run build
```

### Testing

```bash
npm test
```

## RBAC Roles

The UI enforces role-based access control:

- **Security Admin**: Full access to all features
- **Security Engineer**: Full access to all features
- **SRE**: Dashboard, controls, analytics (no report export)
- **Ops Viewer**: Dashboard and environment views only
- **Auditor**: Report export only

## API Configuration

The dashboard connects to the Phase 2 REST API. Configure the API endpoint in `vite.config.ts`:

```typescript
server: {
  proxy: {
    '/api': {
      target: 'https://your-api-endpoint',
      changeOrigin: true,
      secure: false,
    },
  },
}
```

## Development Mode

For local development, the app uses mock user roles stored in localStorage. Set your role:

```javascript
localStorage.setItem('mock_user_role', 'Security Admin');
```

In production, the app uses Azure AD JWT tokens for authentication.

## Live Activity Panel (Issue #207)

**Status:** Enhanced implementation complete

### Overview
The Live Activity Panel provides real-time monitoring of Ralph's orchestration engine with **two distinct views**:

1. **Processed View (Default):** Structured, human-readable summary of agent activity
2. **Raw Log View:** Live log stream from agency session logs with color-coding

### Implementation

#### Core Services
- **`src/services/activityParser.ts`:** Parses orchestration logs from `.squad/orchestration-log/*.md`
- **`src/services/agencyLogTailer.ts`:** NEW - Parses and tails agency session logs from `~/.agency/logs/session_*/`

#### Hooks
- **`src/hooks/useActivityPoller.ts`:** Original poller for orchestration logs
- **`src/hooks/useLiveActivityMonitor.ts`:** NEW - Enhanced monitor supporting both processed and raw views

#### Components
- **`src/components/LiveActivityPanel.tsx`:** Original component for processed view
- **`src/components/EnhancedLiveActivityPanel.tsx`:** NEW - Unified component with view toggle and keyboard shortcuts
- **`src/components/pages/LiveActivityPage.tsx`:** Updated to use enhanced components

### Features Implemented

#### Processed View
- ✅ Agent activity table with status icons (Done/Running/Queued/Failed)
- ✅ Actions log with timestamped event stream
- ✅ Round status bar (number, elapsed time, counts)
- ✅ Auto-refresh every 5 seconds

#### Raw Log View (NEW)
- ✅ Live log stream from agency session logs
- ✅ Color-coding by severity (ERROR=red, WARN=orange, INFO=blue, DEBUG/TRACE=gray)
- ✅ Auto-scroll with pause/resume capability
- ✅ Pattern detection for agent spawns, tool calls, GitHub actions
- ✅ Dark theme console-style display

#### UI/UX Enhancements
- ✅ Toggle between views with toolbar button or keyboard shortcuts
- ✅ Keyboard shortcuts: 'a'/'l' for view toggle, 'p' for pause/resume
- ✅ Auto-scroll indicator in raw view
- ✅ Visual feedback for active view mode

### Data Sources
1. **Orchestration Logs** (`.squad/orchestration-log/*.md`): Structured agent events (spawns, completions, failures)
2. **Agency Session Logs** (`~/.agency/logs/session_*/*.log`): Real-time log stream with structured parsing
3. **Heartbeat JSON** (`~/.squad/ralph-heartbeat.json`): Round status, timing, elapsed seconds

### Pattern Detection
The agency log parser detects:
- **Agent spawns:** "Spawning agent X", "Starting agent X", agent prompts
- **Tool calls:** "Running tool: edit/create/view", "Executing: gh issue/pr"
- **GitHub actions:** issue create/close, PR create/merge, comments
- **Errors:** ERROR/WARN level logs, failure keywords

### Usage

Navigate to `/activity` route in the dashboard (requires `canViewDashboard` permission).

**Keyboard Shortcuts:**
- `a` or `l`: Toggle between processed and raw views
- `p`: Pause/resume auto-scroll (raw view only)

### Implementation Notes

**Mock Data (Current State):**
- Agency log tailing (`findLatestSessionDir`, `tailAgencyLog`) returns mock data
- Full file system integration requires backend API endpoints

**Production Requirements:**
- Backend API to list and read agency session directories
- WebSocket or streaming endpoint for real-time log tailing
- File position tracking for incremental reads

### Future Enhancements
- [ ] Real file system integration (replace mock data with actual file reading via backend API)
- [ ] Duration tracking for running agents (time since spawn)
- [ ] Idle state countdown ("Next round in Xm Ys")
- [ ] Performance optimization (virtualized list for 1000+ log lines)
- [ ] Log filtering by level, agent, or keyword
- [ ] Export logs to file
- [ ] Integration with Ralph heartbeat for active round detection

### Accessing the Panel
Navigate to `/activity` route in the dashboard (requires `canViewDashboard` permission).


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

**Status:** Prototype implementation complete

### Overview
The Live Activity Panel provides real-time monitoring of Ralph's orchestration engine, displaying agent spawns, completions, and current status.

### Implementation
- **Parser Service** (`src/services/activityParser.ts`): Parses orchestration logs from `.squad/orchestration-log/*.md`
- **Custom Hook** (`src/hooks/useActivityPoller.ts`): Polls orchestration logs and heartbeat every 5 seconds
- **React Component** (`src/components/LiveActivityPanel.tsx`): Material-UI table + timeline display
- **Page Component** (`src/components/pages/LiveActivityPage.tsx`): Full-page view with instructions

### Data Sources
1. **Orchestration Logs** (`.squad/orchestration-log/*.md`): Structured agent events (spawns, completions, failures)
2. **Heartbeat JSON** (`~/.squad/ralph-heartbeat.json`): Round status, timing, elapsed seconds

### Features Implemented
- ✅ Agent activity table with status icons (Done/Running/Queued/Failed)
- ✅ Actions log with timestamped event stream
- ✅ Round status bar (number, elapsed time, counts)
- ✅ Auto-refresh every 5 seconds
- ✅ Mock data for demonstration (file system integration pending)

### Future Enhancements
- [ ] Real file system integration (replace mock data with actual file reading)
- [ ] Keyboard shortcuts ('l' for raw logs, 'p' for pause)
- [ ] Duration tracking for running agents (time since spawn)
- [ ] Idle state countdown ("Next round in Xm Ys")
- [ ] Performance optimization (virtualized list for 100+ actions)

### Accessing the Panel
Navigate to `/activity` route in the dashboard (requires `canViewDashboard` permission).


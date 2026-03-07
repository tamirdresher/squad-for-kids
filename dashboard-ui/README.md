# FedRAMP Dashboard UI

React-based UI for the FedRAMP Security Dashboard (Phase 3).

## Features

- **Overview Page**: Real-time compliance status across all environments
- **Control Detail**: Drill-down view for specific FedRAMP controls
- **Environment View**: Per-environment compliance summaries
- **Trend Analysis**: Historical trends and drift detection

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

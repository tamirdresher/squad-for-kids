import React from 'react';
import { Box, Container, Typography, Alert, Button, Chip } from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';
import { EnhancedLiveActivityPanel } from '../EnhancedLiveActivityPanel';
import { useLiveActivityMonitor } from '../../hooks/useLiveActivityMonitor';

/**
 * Live Activity Page
 * 
 * Full-page view for monitoring Ralph's orchestration activity in real-time.
 * Shows agent spawns, completions, and current status.
 * 
 * Features:
 * - Processed view: Structured agent table, round status, actions log
 * - Raw view: Live log stream with color-coding
 * - Keyboard shortcuts: 'a'/'l' to toggle views, 'p' to pause auto-scroll
 */
export const LiveActivityPage: React.FC = () => {
  const {
    viewMode,
    processedState,
    rawLogs,
    loading,
    error,
    toggleViewMode,
    refresh,
  } = useLiveActivityMonitor({
    pollingInterval: 5000,
    enabled: true,
    maxRawLogLines: 500,
  });

  return (
    <Container maxWidth="xl" sx={{ py: 3 }}>
      {/* Header */}
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            Live Agent Activity
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Real-time monitoring of Ralph's orchestration rounds
          </Typography>
        </Box>
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={refresh}
          disabled={loading}
        >
          Refresh
        </Button>
      </Box>

      {/* Info Alert */}
      <Alert severity="info" sx={{ mb: 3 }}>
        <Box display="flex" alignItems="center" gap={2} flexWrap="wrap">
          <Box>
            <strong>Live Monitoring:</strong> This panel monitors Ralph's orchestration in real-time.
          </Box>
          <Box display="flex" gap={1}>
            <Chip label="'a' or 'l' = Toggle view" size="small" variant="outlined" />
            <Chip label="'p' = Pause/Resume" size="small" variant="outlined" />
          </Box>
        </Box>
      </Alert>

      {/* Enhanced Live Activity Panel */}
      <EnhancedLiveActivityPanel
        viewMode={viewMode}
        processedState={processedState}
        rawLogs={rawLogs}
        loading={loading}
        error={error || undefined}
        onToggleView={toggleViewMode}
      />

      {/* Instructions */}
      <Box mt={4}>
        <Typography variant="h6" gutterBottom>
          How It Works
        </Typography>
        
        <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
          Processed View (Default)
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li><strong>Round Status Bar:</strong> Round number, elapsed time, agent/action counts</li>
          <li><strong>Agent Activity Table:</strong> Each agent's status (Done/Running/Queued/Failed), task, duration</li>
          <li><strong>Actions Log:</strong> Timestamped event stream (spawns, completions, failures)</li>
        </ul>

        <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
          Raw Log View
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li><strong>Live Log Stream:</strong> Real-time tail of agency session logs with color-coding by severity</li>
          <li><strong>Error Highlighting:</strong> Errors in red, warnings in orange, info in blue</li>
          <li><strong>Auto-scroll:</strong> Automatically follows new log entries (toggle with 'p' key)</li>
        </ul>

        <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
          Data Sources
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li><strong>Orchestration Logs:</strong> <code>.squad\orchestration-log\*.md</code> (structured agent events)</li>
          <li><strong>Agency Session Logs:</strong> <code>~\.agency\logs\session_*\*.log</code> (live activity stream)</li>
          <li><strong>Heartbeat:</strong> <code>~\.squad\ralph-heartbeat.json</code> (round status, timing)</li>
        </ul>

        <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
          Keyboard Shortcuts
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li><strong>'a' or 'l':</strong> Toggle between processed and raw log views</li>
          <li><strong>'p':</strong> Pause/resume auto-scroll (raw view only)</li>
        </ul>

        <Alert severity="warning" sx={{ mt: 2 }}>
          <strong>Note:</strong> This is a prototype implementation with mock data. 
          Full file system integration for agency logs is pending backend support.
        </Alert>
      </Box>
    </Container>
  );
};

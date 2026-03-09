import React from 'react';
import { Box, Container, Typography, Alert, Button } from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';
import { LiveActivityPanel } from '../LiveActivityPanel';
import { useActivityPoller } from '../../hooks/useActivityPoller';

/**
 * Live Activity Page
 * 
 * Full-page view for monitoring Ralph's orchestration activity in real-time.
 * Shows agent spawns, completions, and current status.
 */
export const LiveActivityPage: React.FC = () => {
  const { state, loading, error, refresh } = useActivityPoller({
    orchestrationLogDir: '.squad/orchestration-log',
    heartbeatFilePath: '.squad/ralph-heartbeat.json',
    pollingInterval: 5000,
    enabled: true,
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
        <strong>Note:</strong> This is a prototype implementation with mock data. 
        In production, this will read from <code>.squad/orchestration-log/</code> and 
        <code>~/.squad/ralph-heartbeat.json</code>.
      </Alert>

      {/* Live Activity Panel */}
      <LiveActivityPanel 
        state={state} 
        loading={loading} 
        error={error || undefined}
      />

      {/* Instructions */}
      <Box mt={4}>
        <Typography variant="h6" gutterBottom>
          How It Works
        </Typography>
        <Typography variant="body2" color="text.secondary" paragraph>
          The live activity panel polls orchestration logs every 5 seconds to display:
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li>
            <strong>Round Status:</strong> Current round number, elapsed time, agent/action counts
          </li>
          <li>
            <strong>Agent Table:</strong> Each agent's status (Done/Running/Queued/Failed), current task, duration
          </li>
          <li>
            <strong>Actions Log:</strong> Timestamped event stream (spawns, completions, failures)
          </li>
        </ul>
        <Typography variant="body2" color="text.secondary" paragraph>
          <strong>Data Sources:</strong>
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li>
            <strong>Orchestration Logs:</strong> <code>.squad\orchestration-log\*.md</code> (structured agent events)
          </li>
          <li>
            <strong>Heartbeat:</strong> <code>~\.squad\ralph-heartbeat.json</code> (round status, timing)
          </li>
        </ul>
        <Typography variant="body2" color="text.secondary" paragraph>
          <strong>Future Enhancements:</strong>
        </Typography>
        <ul style={{ color: 'rgba(0, 0, 0, 0.6)' }}>
          <li>Keyboard shortcuts: 'l' to toggle raw log view, 'p' to pause auto-scroll</li>
          <li>Real file system integration (replace mock data)</li>
          <li>Duration tracking for running agents (time since spawn)</li>
          <li>Idle state countdown: "Next round in 4m 23s"</li>
          <li>Performance optimization: virtualized list for 100+ actions</li>
        </ul>
      </Box>
    </Container>
  );
};

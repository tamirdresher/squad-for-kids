import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
  Chip,
  List,
  ListItem,
  ListItemText,
  Alert,
  CircularProgress,
} from '@mui/material';
import {
  CheckCircle as CheckCircleIcon,
  Sync as SyncIcon,
  HourglassEmpty as HourglassIcon,
  Error as ErrorIcon,
} from '@mui/icons-material';
import { LiveActivityState, AgentRow, ActionEntry } from '../services/activityParser';

interface LiveActivityPanelProps {
  state: LiveActivityState;
  loading?: boolean;
  error?: string;
}

/**
 * Live Agent Activity Panel Component
 * 
 * Displays real-time monitoring of Ralph's orchestration rounds with:
 * - Round status bar (round number, elapsed time, agent count)
 * - Agent activity table (name, status, task, duration)
 * - Actions log (timestamped event stream)
 */
export const LiveActivityPanel: React.FC<LiveActivityPanelProps> = ({ state, loading, error }) => {
  const [autoScroll, setAutoScroll] = useState(true);
  const actionsListRef = React.useRef<HTMLDivElement>(null);

  // Auto-scroll to latest action
  useEffect(() => {
    if (autoScroll && actionsListRef.current) {
      actionsListRef.current.scrollTop = 0;
    }
  }, [state.actions, autoScroll]);

  // Status icon helper
  const getStatusIcon = (status: AgentRow['status']) => {
    switch (status) {
      case '✅ Done':
        return <CheckCircleIcon color="success" />;
      case '🔄 Running':
        return <SyncIcon color="primary" sx={{ animation: 'spin 2s linear infinite' }} />;
      case '⏳ Queued':
        return <HourglassIcon color="disabled" />;
      case '❌ Failed':
        return <ErrorIcon color="error" />;
      default:
        return null;
    }
  };

  // Action type color helper
  const getActionColor = (type: ActionEntry['type']) => {
    switch (type) {
      case 'spawn':
        return 'info';
      case 'complete':
        return 'success';
      case 'fail':
        return 'error';
      default:
        return 'default';
    }
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ m: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box sx={{ p: 2 }}>
      {/* Round Status Bar */}
      <Paper elevation={2} sx={{ p: 2, mb: 3, bgcolor: state.status === 'running' ? 'primary.light' : 'grey.100' }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
          <Typography variant="h6" component="div">
            Round {state.roundNumber} {state.status === 'idle' && '(Idle)'}
          </Typography>
          <Box display="flex" gap={2}>
            <Chip 
              label={`${state.status === 'running' ? 'Running' : 'Idle'} ${state.elapsedTime}s`} 
              color={state.status === 'running' ? 'primary' : 'default'}
            />
            <Chip label={`${state.agents.length} agents`} />
            <Chip label={`${state.actions.length} actions`} />
          </Box>
        </Box>
      </Paper>

      {/* Agent Activity Table */}
      <Paper elevation={1} sx={{ mb: 3 }}>
        <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
          <Typography variant="h6">Agent Activity</Typography>
        </Box>
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Agent</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Current Task</TableCell>
                <TableCell align="right">Duration</TableCell>
                <TableCell>Model</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {state.agents.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} align="center">
                    <Typography variant="body2" color="text.secondary" sx={{ py: 2 }}>
                      No active agents
                    </Typography>
                  </TableCell>
                </TableRow>
              ) : (
                state.agents.map((agent) => (
                  <TableRow key={agent.name} hover>
                    <TableCell>
                      <Box display="flex" alignItems="center" gap={1}>
                        {getStatusIcon(agent.status)}
                        <strong>{agent.name}</strong>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Chip 
                        label={agent.status} 
                        size="small" 
                        color={
                          agent.status === '✅ Done' ? 'success' :
                          agent.status === '🔄 Running' ? 'primary' :
                          agent.status === '❌ Failed' ? 'error' : 'default'
                        }
                      />
                    </TableCell>
                    <TableCell sx={{ maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {agent.currentTask}
                    </TableCell>
                    <TableCell align="right">{agent.duration}</TableCell>
                    <TableCell>
                      <Typography variant="caption" color="text.secondary">
                        {agent.model || '-'}
                      </Typography>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Actions Log */}
      <Paper elevation={1}>
        <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">Actions Log</Typography>
          <Typography variant="caption" color="text.secondary">
            Last updated: {state.lastUpdate.toLocaleTimeString()}
          </Typography>
        </Box>
        <Box 
          ref={actionsListRef}
          sx={{ 
            maxHeight: 400, 
            overflow: 'auto',
            '&::-webkit-scrollbar': { width: '8px' },
            '&::-webkit-scrollbar-thumb': { backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: '4px' },
          }}
        >
          <List dense>
            {state.actions.length === 0 ? (
              <ListItem>
                <ListItemText 
                  primary={
                    <Typography variant="body2" color="text.secondary" align="center">
                      No actions yet
                    </Typography>
                  }
                />
              </ListItem>
            ) : (
              state.actions.map((action, index) => (
                <ListItem 
                  key={index}
                  sx={{ 
                    borderLeft: `4px solid`,
                    borderColor: 
                      action.type === 'spawn' ? 'info.main' :
                      action.type === 'complete' ? 'success.main' :
                      action.type === 'fail' ? 'error.main' : 'grey.400',
                    mb: 1,
                  }}
                >
                  <ListItemText
                    primary={
                      <Box display="flex" gap={1} alignItems="center">
                        <Typography 
                          variant="caption" 
                          sx={{ 
                            fontFamily: 'monospace', 
                            color: 'text.secondary',
                            minWidth: '70px',
                          }}
                        >
                          {action.timestamp}
                        </Typography>
                        <Typography variant="body2">
                          {action.message}
                        </Typography>
                      </Box>
                    }
                  />
                </ListItem>
              ))
            )}
          </List>
        </Box>
      </Paper>

      {/* Idle State Message */}
      {state.status === 'idle' && (
        <Alert severity="info" sx={{ mt: 2 }}>
          Ralph is idle. Next round will start automatically.
        </Alert>
      )}
    </Box>
  );
};

// Add spinning animation to global styles
const style = document.createElement('style');
style.textContent = `
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
`;
document.head.appendChild(style);

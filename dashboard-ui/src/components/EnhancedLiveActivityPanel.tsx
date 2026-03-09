import React, { useState, useEffect, useRef } from 'react';
import {
  Box,
  Paper,
  Typography,
  IconButton,
  Chip,
  Alert,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
} from '@mui/material';
import {
  ViewModule as ViewModuleIcon,
  Code as CodeIcon,
  Pause as PauseIcon,
  PlayArrow as PlayArrowIcon,
} from '@mui/icons-material';
import { LiveActivityState, AgentRow } from '../services/activityParser';
import { LogEntry, getLogLevelColor } from '../services/agencyLogTailer';
import { ViewMode } from '../hooks/useLiveActivityMonitor';

interface EnhancedLiveActivityPanelProps {
  viewMode: ViewMode;
  processedState: LiveActivityState;
  rawLogs: LogEntry[];
  loading?: boolean;
  error?: string;
  onToggleView: () => void;
}

/**
 * Enhanced Live Activity Panel with Raw and Processed Views
 * 
 * Processed View:
 * - Round status bar
 * - Agent activity table
 * - Actions log
 * 
 * Raw View:
 * - Live log stream with color-coding by severity
 * - Auto-scroll with pause option
 */
export const EnhancedLiveActivityPanel: React.FC<EnhancedLiveActivityPanelProps> = ({
  viewMode,
  processedState,
  rawLogs,
  error,
  onToggleView,
}) => {
  const [autoScroll, setAutoScroll] = useState(true);
  const rawLogsRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when new logs arrive
  useEffect(() => {
    if (autoScroll && rawLogsRef.current && viewMode === 'raw') {
      rawLogsRef.current.scrollTop = rawLogsRef.current.scrollHeight;
    }
  }, [rawLogs, autoScroll, viewMode]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      // 'a' or 'l' to toggle view
      if (e.key === 'a' || e.key === 'l') {
        onToggleView();
      }
      // 'p' to pause/resume auto-scroll (only in raw view)
      if (e.key === 'p' && viewMode === 'raw') {
        setAutoScroll(prev => !prev);
      }
    };

    window.addEventListener('keypress', handleKeyPress);
    return () => window.removeEventListener('keypress', handleKeyPress);
  }, [onToggleView, viewMode]);

  if (error) {
    return (
      <Alert severity="error" sx={{ m: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box sx={{ p: 2 }}>
      {/* View Toggle Controls */}
      <Paper elevation={2} sx={{ p: 2, mb: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
          <Box display="flex" alignItems="center" gap={2}>
            <ToggleButtonGroup
              value={viewMode}
              exclusive
              onChange={onToggleView}
              size="small"
            >
              <ToggleButton value="processed">
                <Tooltip title="Processed View (a)">
                  <Box display="flex" alignItems="center" gap={1}>
                    <ViewModuleIcon />
                    <Typography variant="button">Processed</Typography>
                  </Box>
                </Tooltip>
              </ToggleButton>
              <ToggleButton value="raw">
                <Tooltip title="Raw Logs (l)">
                  <Box display="flex" alignItems="center" gap={1}>
                    <CodeIcon />
                    <Typography variant="button">Raw</Typography>
                  </Box>
                </Tooltip>
              </ToggleButton>
            </ToggleButtonGroup>

            {viewMode === 'raw' && (
              <Tooltip title={autoScroll ? 'Pause Auto-scroll (p)' : 'Resume Auto-scroll (p)'}>
                <IconButton
                  size="small"
                  onClick={() => setAutoScroll(!autoScroll)}
                  color={autoScroll ? 'primary' : 'default'}
                >
                  {autoScroll ? <PauseIcon /> : <PlayArrowIcon />}
                </IconButton>
              </Tooltip>
            )}
          </Box>

          <Box display="flex" gap={2}>
            <Chip
              label={`Round ${processedState.roundNumber}`}
              color={processedState.status === 'running' ? 'primary' : 'default'}
            />
            <Chip label={`${rawLogs.length} log lines`} />
          </Box>
        </Box>
      </Paper>

      {/* Processed View */}
      {viewMode === 'processed' && (
        <ProcessedView state={processedState} />
      )}

      {/* Raw View */}
      {viewMode === 'raw' && (
        <RawLogsView logs={rawLogs} logsRef={rawLogsRef} autoScroll={autoScroll} />
      )}
    </Box>
  );
};

/**
 * Processed View Component (existing functionality)
 */
const ProcessedView: React.FC<{ state: LiveActivityState }> = ({ state }) => {
  return (
    <>
      {/* Round Status Bar */}
      <Paper elevation={1} sx={{ p: 2, mb: 3, bgcolor: state.status === 'running' ? 'primary.light' : 'grey.100' }}>
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
        <Box sx={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #e0e0e0' }}>
                <th style={{ padding: '12px', textAlign: 'left' }}>Agent</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>Status</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>Current Task</th>
                <th style={{ padding: '12px', textAlign: 'right' }}>Duration</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>Model</th>
              </tr>
            </thead>
            <tbody>
              {state.agents.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ padding: '20px', textAlign: 'center', color: '#757575' }}>
                    No active agents
                  </td>
                </tr>
              ) : (
                state.agents.map((agent) => (
                  <tr key={agent.name} style={{ borderBottom: '1px solid #f0f0f0' }}>
                    <td style={{ padding: '12px' }}>
                      <strong>{agent.name}</strong>
                    </td>
                    <td style={{ padding: '12px' }}>
                      <Chip
                        label={agent.status}
                        size="small"
                        color={getAgentStatusColor(agent.status)}
                      />
                    </td>
                    <td style={{ padding: '12px', maxWidth: '400px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {agent.currentTask}
                    </td>
                    <td style={{ padding: '12px', textAlign: 'right' }}>{agent.duration}</td>
                    <td style={{ padding: '12px', fontSize: '0.875rem', color: '#757575' }}>
                      {agent.model || '-'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </Box>
      </Paper>

      {/* Actions Log */}
      <Paper elevation={1}>
        <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', display: 'flex', justifyContent: 'space-between' }}>
          <Typography variant="h6">Actions Log</Typography>
          <Typography variant="caption" color="text.secondary">
            Last updated: {state.lastUpdate.toLocaleTimeString()}
          </Typography>
        </Box>
        <Box sx={{ maxHeight: 400, overflow: 'auto' }}>
          {state.actions.length === 0 ? (
            <Typography variant="body2" color="text.secondary" align="center" sx={{ py: 2 }}>
              No actions yet
            </Typography>
          ) : (
            state.actions.map((action, index) => (
              <Box
                key={index}
                sx={{
                  borderLeft: `4px solid`,
                  borderColor: getActionColor(action.type),
                  p: 1.5,
                  mb: 1,
                }}
              >
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
                  <Typography variant="body2">{action.message}</Typography>
                </Box>
              </Box>
            ))
          )}
        </Box>
      </Paper>
    </>
  );
};

/**
 * Raw Logs View Component
 */
const RawLogsView: React.FC<{
  logs: LogEntry[];
  logsRef: React.RefObject<HTMLDivElement>;
  autoScroll: boolean;
}> = ({ logs, logsRef, autoScroll }) => {
  return (
    <Paper elevation={1}>
      <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h6">Live Log Stream</Typography>
        <Box display="flex" gap={2} alignItems="center">
          <Typography variant="caption" color="text.secondary">
            {logs.length} lines
          </Typography>
          {autoScroll && (
            <Chip label="Auto-scroll" size="small" color="primary" />
          )}
        </Box>
      </Box>
      <Box
        ref={logsRef}
        sx={{
          height: 600,
          overflow: 'auto',
          bgcolor: '#1e1e1e',
          color: '#d4d4d4',
          fontFamily: 'Consolas, "Courier New", monospace',
          fontSize: '0.85rem',
          p: 2,
          '&::-webkit-scrollbar': { width: '10px' },
          '&::-webkit-scrollbar-thumb': {
            backgroundColor: 'rgba(255,255,255,0.3)',
            borderRadius: '5px',
          },
        }}
      >
        {logs.length === 0 ? (
          <Typography variant="body2" sx={{ color: '#888' }}>
            No logs yet. Waiting for activity...
          </Typography>
        ) : (
          logs.map((log, index) => (
            <Box key={index} sx={{ mb: 0.5, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
              <Typography
                component="span"
                sx={{
                  color: getLogLevelColor(log.level),
                  fontWeight: log.level === 'ERROR' ? 'bold' : 'normal',
                }}
              >
                {log.raw}
              </Typography>
            </Box>
          ))
        )}
      </Box>
    </Paper>
  );
};

// Helper functions
function getAgentStatusColor(status: AgentRow['status']): 'success' | 'primary' | 'error' | 'default' {
  if (status === '✅ Done') return 'success';
  if (status === '🔄 Running') return 'primary';
  if (status === '❌ Failed') return 'error';
  return 'default';
}

function getActionColor(type: string): string {
  switch (type) {
    case 'spawn':
      return '#2196f3'; // blue
    case 'complete':
      return '#4caf50'; // green
    case 'fail':
      return '#f44336'; // red
    default:
      return '#9e9e9e'; // gray
  }
}

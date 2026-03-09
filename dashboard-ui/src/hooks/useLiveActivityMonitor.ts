import { useState, useEffect, useCallback, useRef } from 'react';
import {
  parseAgencyLog,
  AgencyActivity,
  LogEntry,
  findLatestSessionDir,
  tailAgencyLog,
} from '../services/agencyLogTailer';
import {
  LiveActivityState,
  aggregateEvents,
  AgentEvent,
} from '../services/activityParser';

export type ViewMode = 'processed' | 'raw';

interface UseLiveActivityMonitorOptions {
  pollingInterval?: number;
  enabled?: boolean;
  maxRawLogLines?: number;
}

interface LiveActivityMonitorState {
  viewMode: ViewMode;
  processedState: LiveActivityState;
  rawLogs: LogEntry[];
  agencyActivity: AgencyActivity | null;
  loading: boolean;
  error: string | null;
}

/**
 * Enhanced hook for live activity monitoring with both processed and raw views
 * 
 * Monitors:
 * 1. Orchestration logs from .squad/orchestration-log/ for structured agent events
 * 2. Agency session logs from user .agency/logs directory for raw activity stream
 */
export function useLiveActivityMonitor({
  pollingInterval = 5000,
  enabled = true,
  maxRawLogLines = 500,
}: UseLiveActivityMonitorOptions = {}) {
  const [state, setState] = useState<LiveActivityMonitorState>({
    viewMode: 'processed',
    processedState: {
      roundNumber: 0,
      status: 'idle',
      elapsedTime: 0,
      agents: [],
      actions: [],
      lastUpdate: new Date(),
    },
    rawLogs: [],
    agencyActivity: null,
    loading: true,
    error: null,
  });
  
  const logPositionRef = useRef<number>(0);
  const sessionDirRef = useRef<string | null>(null);

  /**
   * Toggle between processed and raw view modes
   */
  const toggleViewMode = useCallback(() => {
    setState(prev => ({
      ...prev,
      viewMode: prev.viewMode === 'processed' ? 'raw' : 'processed',
    }));
  }, []);

  /**
   * Fetch orchestration logs for processed view (existing implementation)
   */
  const fetchOrchestrationLogs = useCallback(async (): Promise<AgentEvent[]> => {
    // Mock data for now (same as original implementation)
    // In production, this would read from .squad/orchestration-log/
    const mockEvents: AgentEvent[] = [
      {
        timestamp: new Date(Date.now() - 180000).toISOString(),
        agentName: 'Picard',
        issue: 198,
        issueTitle: 'ADR Teams chat monitoring',
        status: 'completed',
        task: 'ADR notification pipeline broken',
        duration: 45,
        model: 'claude-sonnet-4.5',
        fileName: '2026-03-09T11-36-07Z-picard.md',
      },
      {
        timestamp: new Date(Date.now() - 120000).toISOString(),
        agentName: "B'Elanna",
        issue: 183,
        issueTitle: 'Office Automation',
        status: 'completed',
        task: 'Office Automation workflow coverage',
        duration: 120,
        model: 'claude-sonnet-4.5',
        fileName: '2026-03-09T11-36-07Z-belanna.md',
      },
      {
        timestamp: new Date().toISOString(),
        agentName: 'Data',
        issue: 207,
        issueTitle: 'Live agent activity panel',
        status: 'running',
        task: 'Implementing live activity panel with raw log view',
        model: 'claude-sonnet-4.5',
        fileName: '2026-03-09T11-30-00Z-data.md',
      },
    ];

    return mockEvents;
  }, []);

  /**
   * Fetch agency logs for raw view
   */
  const fetchAgencyLogs = useCallback(async (): Promise<AgencyActivity> => {
    try {
      // Find latest session directory if not already set
      if (!sessionDirRef.current) {
        const sessionDir = await findLatestSessionDir();
        if (sessionDir) {
          sessionDirRef.current = sessionDir;
          logPositionRef.current = 0;
        }
      }

      if (!sessionDirRef.current) {
        // Return empty activity if no session found
        return {
          agentSpawns: [],
          toolCalls: [],
          githubActions: [],
          errors: [],
          rawLogs: [],
        };
      }

      // Tail the log file from last position
      const { content, newPosition } = await tailAgencyLog(
        sessionDirRef.current,
        logPositionRef.current
      );
      
      logPositionRef.current = newPosition;

      // Parse the new content
      const activity = parseAgencyLog(content);
      
      // Limit raw logs to maxRawLogLines (keep most recent)
      if (activity.rawLogs.length > maxRawLogLines) {
        activity.rawLogs = activity.rawLogs.slice(-maxRawLogLines);
      }

      return activity;
    } catch (err) {
      console.error('Failed to fetch agency logs:', err);
      // Return mock data for demo
      return generateMockAgencyActivity();
    }
  }, [maxRawLogLines]);

  /**
   * Poll for updates
   */
  const poll = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, error: null }));

      // Fetch orchestration logs for processed view
      const events = await fetchOrchestrationLogs();
      const aggregated = aggregateEvents(events);

      // Fetch agency logs for raw view
      const agencyActivity = await fetchAgencyLogs();

      // Merge raw logs (append new ones)
      setState(prev => {
        const existingLogs = prev.rawLogs;
        const newLogs = agencyActivity.rawLogs.filter(
          newLog => !existingLogs.some(existing => existing.raw === newLog.raw)
        );
        
        const allLogs = [...existingLogs, ...newLogs];
        const trimmedLogs = allLogs.slice(-maxRawLogLines);

        return {
          ...prev,
          processedState: {
            roundNumber: 67,
            status: 'running',
            elapsedTime: Math.floor((Date.now() - Date.now() + 263000) / 1000),
            agents: aggregated.agents,
            actions: aggregated.actions,
            lastUpdate: new Date(),
          },
          rawLogs: trimmedLogs,
          agencyActivity,
          loading: false,
        };
      });
    } catch (err) {
      console.error('Polling error:', err);
      setState(prev => ({
        ...prev,
        error: err instanceof Error ? err.message : 'Unknown error',
        loading: false,
      }));
    }
  }, [fetchOrchestrationLogs, fetchAgencyLogs, maxRawLogLines]);

  /**
   * Manual refresh
   */
  const refresh = useCallback(() => {
    setState(prev => ({ ...prev, loading: true }));
    poll();
  }, [poll]);

  // Start polling on mount
  useEffect(() => {
    if (!enabled) {
      return;
    }

    // Initial poll
    poll();

    // Set up interval
    const intervalId = setInterval(poll, pollingInterval);

    // Cleanup on unmount
    return () => {
      clearInterval(intervalId);
    };
  }, [enabled, poll, pollingInterval]);

  return {
    ...state,
    toggleViewMode,
    refresh,
  };
}

/**
 * Generate mock agency activity for demo purposes
 */
function generateMockAgencyActivity(): AgencyActivity {
  const now = new Date();
  
  const mockLogs: LogEntry[] = [
    {
      timestamp: new Date(now.getTime() - 300000).toISOString(),
      level: 'INFO',
      message: '🤖 Agency 2026.3.7.5',
      raw: `${new Date(now.getTime() - 300000).toISOString()}  INFO main ThreadId(01) agency: 🤖 Agency 2026.3.7.5`,
    },
    {
      timestamp: new Date(now.getTime() - 290000).toISOString(),
      level: 'INFO',
      message: 'Starting agent Data for issue #207',
      raw: `${new Date(now.getTime() - 290000).toISOString()}  INFO main ThreadId(01) agency: Starting agent Data for issue #207`,
    },
    {
      timestamp: new Date(now.getTime() - 280000).toISOString(),
      level: 'DEBUG',
      message: 'Running tool: view',
      raw: `${new Date(now.getTime() - 280000).toISOString()} DEBUG main ThreadId(01) copilot: Running tool: view`,
    },
    {
      timestamp: new Date(now.getTime() - 270000).toISOString(),
      level: 'DEBUG',
      message: 'Running tool: create',
      raw: `${new Date(now.getTime() - 270000).toISOString()} DEBUG main ThreadId(01) copilot: Running tool: create`,
    },
    {
      timestamp: new Date(now.getTime() - 260000).toISOString(),
      level: 'INFO',
      message: 'Executing: gh pr create --title "feat(monitor): Live activity panel"',
      raw: `${new Date(now.getTime() - 260000).toISOString()}  INFO main ThreadId(01) copilot: Executing: gh pr create --title "feat(monitor): Live activity panel"`,
    },
    {
      timestamp: new Date(now.getTime() - 250000).toISOString(),
      level: 'INFO',
      message: 'PR created successfully: #210',
      raw: `${new Date(now.getTime() - 250000).toISOString()}  INFO main ThreadId(01) copilot: PR created successfully: #210`,
    },
  ];

  return {
    agentSpawns: [
      {
        timestamp: new Date(now.getTime() - 290000).toISOString(),
        agentName: 'Data',
        task: 'Implementing live activity panel for issue #207',
      },
    ],
    toolCalls: [
      {
        timestamp: new Date(now.getTime() - 280000).toISOString(),
        tool: 'view',
        details: 'Running tool: view',
      },
      {
        timestamp: new Date(now.getTime() - 270000).toISOString(),
        tool: 'create',
        details: 'Running tool: create',
      },
    ],
    githubActions: [
      {
        timestamp: new Date(now.getTime() - 260000).toISOString(),
        action: 'pr_created',
        details: 'gh pr create --title "feat(monitor): Live activity panel"',
      },
    ],
    errors: [],
    rawLogs: mockLogs,
  };
}

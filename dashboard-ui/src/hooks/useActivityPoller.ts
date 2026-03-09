import { useState, useEffect, useCallback } from 'react';
import { 
  LiveActivityState, 
  AgentEvent, 
  parseOrchestrationLog, 
  aggregateEvents,
  formatElapsedTime
} from '../services/activityParser';

interface UseActivityPollerOptions {
  orchestrationLogDir: string;
  heartbeatFilePath?: string;
  pollingInterval?: number; // milliseconds
  enabled?: boolean;
}

interface HeartbeatData {
  round: number;
  status: 'idle' | 'running';
  timestamp: string;
  elapsedSeconds?: number;
}

/**
 * Custom hook for polling orchestration logs and heartbeat
 * 
 * Polls .squad/orchestration-log/ directory for new agent events
 * and aggregates them into live activity state.
 */
export function useActivityPoller({
  orchestrationLogDir,
  heartbeatFilePath,
  pollingInterval = 5000,
  enabled = true,
}: UseActivityPollerOptions) {
  const [state, setState] = useState<LiveActivityState>({
    roundNumber: 0,
    status: 'idle',
    elapsedTime: 0,
    agents: [],
    actions: [],
    lastUpdate: new Date(),
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [events, setEvents] = useState<AgentEvent[]>([]);

  /**
   * Parse heartbeat file to get round status
   */
  const fetchHeartbeat = useCallback(async (): Promise<HeartbeatData | null> => {
    if (!heartbeatFilePath) {
      return null;
    }

    try {
      // In a real implementation, this would use the file system API
      // For now, return mock data
      return {
        round: 67,
        status: 'running',
        timestamp: new Date().toISOString(),
        elapsedSeconds: 263,
      };
    } catch (err) {
      console.error('Failed to fetch heartbeat:', err);
      return null;
    }
  }, [heartbeatFilePath]);

  /**
   * Scan orchestration log directory for new events
   */
  const fetchOrchestrationLogs = useCallback(async (): Promise<AgentEvent[]> => {
    try {
      // In a real implementation, this would:
      // 1. List files in orchestrationLogDir
      // 2. Filter by modification time (since last poll)
      // 3. Read file contents
      // 4. Parse with parseOrchestrationLog()
      
      // For now, return mock data based on existing logs
      const mockEvents: AgentEvent[] = [
        {
          timestamp: '2026-03-09T11:36:07Z',
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
          timestamp: '2026-03-09T11:36:07Z',
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
          timestamp: '2026-03-09T11:30:00Z',
          agentName: 'Data',
          issue: 207,
          issueTitle: 'Live agent activity panel',
          status: 'running',
          task: 'Implementing live activity panel',
          model: 'claude-sonnet-4.5',
          fileName: '2026-03-09T11-30-00Z-data.md',
        },
      ];

      return mockEvents;
    } catch (err) {
      console.error('Failed to fetch orchestration logs:', err);
      throw err;
    }
  }, [orchestrationLogDir]);

  /**
   * Poll for new data
   */
  const poll = useCallback(async () => {
    try {
      setError(null);
      
      // Fetch heartbeat (optional)
      const heartbeat = await fetchHeartbeat();
      
      // Fetch orchestration logs
      const newEvents = await fetchOrchestrationLogs();
      setEvents(newEvents);
      
      // Aggregate into state
      const aggregated = aggregateEvents(newEvents);
      
      setState({
        roundNumber: heartbeat?.round || 67,
        status: heartbeat?.status || 'running',
        elapsedTime: heartbeat?.elapsedSeconds || 0,
        agents: aggregated.agents,
        actions: aggregated.actions,
        lastUpdate: new Date(),
      });
      
      setLoading(false);
    } catch (err) {
      console.error('Polling error:', err);
      setError(err instanceof Error ? err.message : 'Unknown error');
      setLoading(false);
    }
  }, [fetchHeartbeat, fetchOrchestrationLogs]);

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
    state,
    loading,
    error,
    events,
    refresh: poll,
  };
}

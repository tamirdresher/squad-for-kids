/**
 * Activity Parser Service
 * 
 * Parses orchestration logs from .squad/orchestration-log/ directory
 * to extract structured agent activity events for the live activity panel.
 * 
 * File format: YYYY-MM-DDTHH-mm-ssZ-{agent}.md
 * Structure: Markdown with structured headers (Agent, Issue, Timestamp, Status)
 */

export interface AgentEvent {
  timestamp: string;
  agentName: string;
  issue?: number;
  issueTitle?: string;
  status: 'spawned' | 'running' | 'completed' | 'failed';
  task: string;
  duration?: number;
  model?: string;
  fileName: string;
}

export interface LiveActivityState {
  roundNumber: number;
  status: 'idle' | 'running' | 'error';
  elapsedTime: number;
  agents: AgentRow[];
  actions: ActionEntry[];
  lastUpdate: Date;
}

export interface AgentRow {
  name: string;
  status: '✅ Done' | '🔄 Running' | '⏳ Queued' | '❌ Failed';
  currentTask: string;
  duration: string;
  model?: string;
}

export interface ActionEntry {
  timestamp: string;
  message: string;
  type: 'spawn' | 'complete' | 'fail' | 'round_start' | 'round_end';
}

/**
 * Parse a single orchestration log file
 */
export function parseOrchestrationLog(content: string, fileName: string): AgentEvent | null {
  try {
    // Extract timestamp from filename: 2026-03-09T11-36-07Z-belanna.md
    const fileNameMatch = fileName.match(/(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z)-(.+)\.md$/);
    if (!fileNameMatch) {
      return null;
    }
    
    const [, timestamp, agentName] = fileNameMatch;
    const isoTimestamp = timestamp.replace(/-(\d{2})-(\d{2})Z$/, ':$1:$2Z');
    
    // Parse markdown headers
    const agentMatch = content.match(/\*\*Agent:\*\*\s+(.+?)(?:\((.+?)\))?$/m);
    const issueMatch = content.match(/\*\*Issue:\*\*\s+#(\d+)\s*[—–-]\s*(.+?)$/m);
    const statusMatch = content.match(/\*\*Status:\*\*\s+(.+?)$/m);
    const workSummaryMatch = content.match(/## Work Summary\s+([\s\S]+?)(?=\n##|$)/);
    
    const agent = agentMatch ? agentMatch[1].trim() : agentName;
    const model = agentMatch && agentMatch[2] ? agentMatch[2].trim() : undefined;
    const issue = issueMatch ? parseInt(issueMatch[1], 10) : undefined;
    const issueTitle = issueMatch ? issueMatch[2].trim() : undefined;
    const statusRaw = statusMatch ? statusMatch[1].trim().toUpperCase() : 'RUNNING';
    const workSummary = workSummaryMatch ? workSummaryMatch[1].trim() : '';
    
    // Determine status
    let status: AgentEvent['status'];
    if (statusRaw === 'DONE') {
      status = 'completed';
    } else if (statusRaw === 'FAILED') {
      status = 'failed';
    } else {
      status = 'running';
    }
    
    // Extract task description (first line of work summary, truncated)
    const taskLines = workSummary.split('\n').filter(l => l.trim() && !l.startsWith('-'));
    const task = taskLines.length > 0 
      ? taskLines[0].replace(/^\*\*[^*]+\*\*:?\s*/, '').trim().substring(0, 80)
      : issueTitle || 'Unknown task';
    
    return {
      timestamp: isoTimestamp,
      agentName: agent,
      issue,
      issueTitle,
      status,
      task,
      model,
      fileName,
    };
  } catch (error) {
    console.error(`Failed to parse orchestration log ${fileName}:`, error);
    return null;
  }
}

/**
 * Aggregate events into live activity state
 */
export function aggregateEvents(events: AgentEvent[]): Omit<LiveActivityState, 'roundNumber' | 'status' | 'elapsedTime'> {
  // Sort events by timestamp (newest first for actions, but track all for agent table)
  const sortedEvents = [...events].sort((a, b) => 
    new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
  );
  
  // Build agent table (latest status per agent)
  const agentMap = new Map<string, AgentEvent>();
  for (const event of events) {
    const existing = agentMap.get(event.agentName);
    if (!existing || new Date(event.timestamp) > new Date(existing.timestamp)) {
      agentMap.set(event.agentName, event);
    }
  }
  
  const agents: AgentRow[] = Array.from(agentMap.values()).map(event => {
    let status: AgentRow['status'];
    if (event.status === 'completed') {
      status = '✅ Done';
    } else if (event.status === 'failed') {
      status = '❌ Failed';
    } else if (event.status === 'running') {
      status = '🔄 Running';
    } else {
      status = '⏳ Queued';
    }
    
    // Calculate duration if completed/failed
    let duration = '-';
    if (event.duration) {
      const minutes = Math.floor(event.duration / 60);
      const seconds = event.duration % 60;
      duration = minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
    }
    
    return {
      name: event.agentName,
      status,
      currentTask: event.task,
      duration,
      model: event.model,
    };
  });
  
  // Build actions log (last 20 events)
  const actions: ActionEntry[] = sortedEvents.slice(0, 20).map(event => {
    const time = new Date(event.timestamp).toLocaleTimeString('en-US', { 
      hour12: false, 
      hour: '2-digit', 
      minute: '2-digit', 
      second: '2-digit' 
    });
    
    let message: string;
    let type: ActionEntry['type'];
    
    if (event.status === 'completed') {
      message = `${event.agentName} completed ${event.issue ? `#${event.issue}` : 'task'}`;
      type = 'complete';
    } else if (event.status === 'failed') {
      message = `${event.agentName} failed on ${event.issue ? `#${event.issue}` : 'task'}`;
      type = 'fail';
    } else {
      message = `Spawned ${event.agentName} (${event.task})`;
      type = 'spawn';
    }
    
    return {
      timestamp: time,
      message,
      type,
    };
  });
  
  return {
    agents,
    actions,
    lastUpdate: new Date(),
  };
}

/**
 * Format elapsed time (seconds to human-readable)
 */
export function formatElapsedTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  
  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

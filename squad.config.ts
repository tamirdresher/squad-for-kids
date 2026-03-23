import type { SquadConfig } from '@bradygaster/squad';

/**
 * Squad Configuration for tamresearch1
 * 
 */
const config: SquadConfig = {
  version: '1.0.0',
  
  models: {
    defaultModel: 'claude-sonnet-4.5',
    defaultTier: 'standard',
    fallbackChains: {
      premium: ['claude-opus-4.6', 'claude-opus-4.6-fast', 'claude-opus-4.5', 'claude-sonnet-4.5'],
      standard: ['claude-sonnet-4.5', 'gpt-5.2-codex', 'claude-sonnet-4', 'gpt-5.2'],
      fast: ['claude-haiku-4.5', 'gpt-5.1-codex-mini', 'gpt-4.1', 'gpt-5-mini']
    },
    preferSameProvider: true,
    respectTierCeiling: true,
    nuclearFallback: {
      enabled: false,
      model: 'claude-haiku-4.5',
      maxRetriesBeforeNuclear: 3
    }
  },
  
  routing: {
    rules: [
      {
        workType: 'feature-dev',
        agents: ['@scribe'],
        confidence: 'high',
        // Feature tasks must use the 5-phase pipeline defined in .squad/orchestration-pipeline.md
        pipeline: 'five-phase',
        pipelineRef: '.squad/orchestration-pipeline.md'
      },
      {
        workType: 'refactor',
        agents: ['@scribe'],
        confidence: 'high',
        // Multi-file refactors use the 5-phase pipeline
        pipeline: 'five-phase',
        pipelineRef: '.squad/orchestration-pipeline.md'
      },
      {
        workType: 'bug-fix',
        agents: ['@scribe'],
        confidence: 'high'
      },
      {
        workType: 'testing',
        agents: ['@scribe'],
        confidence: 'high'
      },
      {
        workType: 'documentation',
        agents: ['@scribe'],
        confidence: 'high'
      }
    ],
    governance: {
      eagerByDefault: true,
      scribeAutoRuns: false,
      allowRecursiveSpawn: false,
      // Enforce 5-phase pipeline for feature-level work; see .squad/orchestration-pipeline.md
      enforcePhaseSequencing: true,
      pipelineRef: '.squad/orchestration-pipeline.md',
      // Iterative retrieval pattern (Issue #1317): sub-agents may perform at most
      // maxSubAgentCycles investigation cycles before returning results. The
      // coordinator evaluates every return before accepting it. Delegation prompts
      // must include WHY (objective context) not just WHAT.
      maxSubAgentCycles: 3,
      requireObjectiveContext: true,
      coordinatorEvaluatesReturns: true
    }
  },
  
  casting: {
    allowlistUniverses: [
      'The Usual Suspects',
      'Breaking Bad',
      'The Wire',
      'Firefly'
    ],
    overflowStrategy: 'generic',
    universeCapacity: {}
  },
  
  platforms: {
    vscode: {
      disableModelSelection: false,
      scribeMode: 'sync'
    }
  }
};

export default config;

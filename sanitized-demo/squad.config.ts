import { SquadConfig } from '@bradygaster/squad';

export default {
  models: {
    premium: ['claude-opus-4', 'gpt-4-turbo'],
    standard: ['claude-sonnet-3.5', 'gpt-4'],
    fast: ['claude-haiku-3', 'gpt-3.5-turbo'],
    fallbackChain: ['premium', 'standard', 'fast']
  },
  
  routing: {
    rules: [
      {
        workType: 'security-review',
        agents: ['@worf'],
        confidence: 'high'
      },
      {
        workType: 'infrastructure',
        agents: ['@belanna'],
        confidence: 'high'
      },
      {
        workType: 'code-implementation',
        agents: ['@data', '@scribe'],
        confidence: 'high'
      },
      {
        workType: 'documentation',
        agents: ['@seven'],
        confidence: 'high'
      },
      {
        workType: 'triage',
        agents: ['@picard'],
        confidence: 'high'
      }
    ]
  },
  
  casting: {
    universeAllowlist: [
      'Star Trek TNG',
      'Star Trek Voyager',
      'Star Trek DS9'
    ],
    overflowStrategy: 'queue'
  },
  
  governance: {
    eagerByDefault: false,
    scribeAutoRuns: true,
    allowRecursiveSpawn: false
  },
  
  platforms: {
    vscode: {
      autoOpenFiles: true
    },
    cli: {
      interactive: false
    }
  }
} satisfies SquadConfig;

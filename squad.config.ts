import type { SquadConfig } from '@bradygaster/squad';

/**
 * Squad Configuration for kids-squad-setup
 * גרסת ילדים — מודלים חינמיים/זולים, ניתוב פשוט
 */
const config: SquadConfig = {
  version: '1.0.0',

  models: {
    // שימוש במודלים חינמיים (Copilot Free Tier) או זולים
    defaultModel: 'gpt-4.1',
    defaultTier: 'fast',
    fallbackChains: {
      premium: ['claude-sonnet-4', 'gpt-5.1', 'claude-sonnet-4.5'],
      standard: ['gpt-4.1', 'gpt-5-mini', 'claude-haiku-4.5'],
      fast: ['gpt-5-mini', 'gpt-4.1', 'claude-haiku-4.5']
    },
    preferSameProvider: true,
    respectTierCeiling: true,
    nuclearFallback: {
      enabled: true,
      model: 'gpt-5-mini',
      maxRetriesBeforeNuclear: 2
    }
  },

  routing: {
    rules: [
      {
        // שיעורי בית ולמידה
        workType: 'homework',
        agents: ['@copilot'],
        confidence: 'high'
      },
      {
        // פרויקטים של קוד
        workType: 'feature-dev',
        agents: ['@copilot'],
        confidence: 'high'
      },
      {
        // תיקון באגים
        workType: 'bug-fix',
        agents: ['@copilot'],
        confidence: 'high'
      },
      {
        // תיעוד ועזרה
        workType: 'documentation',
        agents: ['@copilot'],
        confidence: 'high'
      }
    ],
    governance: {
      eagerByDefault: true,
      scribeAutoRuns: false,
      allowRecursiveSpawn: false
    }
  },

  casting: {
    allowlistUniverses: [
      'Minecraft',
      'Harry Potter',
      'Star Wars',
      'Pokemon'
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

/**
 * SDK-First Mode Compatibility Test
 * 
 * Tests whether our legacy SquadConfig (from @bradygaster/squad) can be
 * mapped to the new SDK-first defineSquad() builders (from @bradygaster/squad-sdk).
 * 
 * Issue: https://github.com/tamirdresher_microsoft/tamresearch1/issues/663
 */

import {
  defineSquad,
  defineTeam,
  defineAgent,
  defineRouting,
  defineCasting,
  BuilderValidationError,
} from '@bradygaster/squad-sdk';

import type {
  SquadSDKConfig,
  TeamDefinition,
  AgentDefinition,
  RoutingDefinition,
  CastingDefinition,
} from '@bradygaster/squad-sdk';

// ============================================================================
// Our current legacy config (from squad.config.ts)
// ============================================================================

interface LegacySquadConfig {
  version: string;
  models: {
    defaultModel: string;
    defaultTier: string;
    fallbackChains: Record<string, string[]>;
    preferSameProvider: boolean;
    respectTierCeiling: boolean;
    nuclearFallback: {
      enabled: boolean;
      model: string;
      maxRetriesBeforeNuclear: number;
    };
  };
  routing: {
    rules: Array<{
      workType: string;
      agents: string[];
      confidence: string;
    }>;
    governance: {
      eagerByDefault: boolean;
      scribeAutoRuns: boolean;
      allowRecursiveSpawn: boolean;
    };
  };
  casting: {
    allowlistUniverses: string[];
    overflowStrategy: string;
    universeCapacity: Record<string, number>;
  };
  platforms: {
    vscode: {
      disableModelSelection: boolean;
      scribeMode: string;
    };
  };
}

const LEGACY_CONFIG: LegacySquadConfig = {
  version: '1.0.0',
  models: {
    defaultModel: 'claude-sonnet-4.5',
    defaultTier: 'standard',
    fallbackChains: {
      premium: ['claude-opus-4.6', 'claude-opus-4.6-fast', 'claude-opus-4.5', 'claude-sonnet-4.5'],
      standard: ['claude-sonnet-4.5', 'gpt-5.2-codex', 'claude-sonnet-4', 'gpt-5.2'],
      fast: ['claude-haiku-4.5', 'gpt-5.1-codex-mini', 'gpt-4.1', 'gpt-5-mini'],
    },
    preferSameProvider: true,
    respectTierCeiling: true,
    nuclearFallback: {
      enabled: false,
      model: 'claude-haiku-4.5',
      maxRetriesBeforeNuclear: 3,
    },
  },
  routing: {
    rules: [
      { workType: 'feature-dev', agents: ['@scribe'], confidence: 'high' },
      { workType: 'bug-fix', agents: ['@scribe'], confidence: 'high' },
      { workType: 'testing', agents: ['@scribe'], confidence: 'high' },
      { workType: 'documentation', agents: ['@scribe'], confidence: 'high' },
    ],
    governance: {
      eagerByDefault: true,
      scribeAutoRuns: false,
      allowRecursiveSpawn: false,
    },
  },
  casting: {
    allowlistUniverses: ['The Usual Suspects', 'Breaking Bad', 'The Wire', 'Firefly'],
    overflowStrategy: 'generic',
    universeCapacity: {},
  },
  platforms: {
    vscode: {
      disableModelSelection: false,
      scribeMode: 'sync',
    },
  },
};

// ============================================================================
// Compatibility analysis
// ============================================================================

interface CompatResult {
  feature: string;
  legacyValue: unknown;
  sdkEquivalent: string | null;
  status: '✅ compatible' | '⚠️ partial' | '❌ no equivalent' | '🆕 sdk-only';
  notes: string;
}

const results: CompatResult[] = [];

// --- Test 1: version ---
results.push({
  feature: 'version',
  legacyValue: LEGACY_CONFIG.version,
  sdkEquivalent: 'SquadSDKConfig.version',
  status: '✅ compatible',
  notes: 'Both schemas support version string.',
});

// --- Test 2: models.defaultModel ---
results.push({
  feature: 'models.defaultModel',
  legacyValue: LEGACY_CONFIG.models.defaultModel,
  sdkEquivalent: 'defineDefaults({ model })',
  status: '⚠️ partial',
  notes: 'SDK supports defaults.model as string or ModelPreference { preferred, fallback, rationale }. ' +
    'Maps to defineDefaults({ model: "claude-sonnet-4.5" }). But only ONE fallback, not a chain.',
});

// --- Test 3: models.fallbackChains ---
results.push({
  feature: 'models.fallbackChains',
  legacyValue: LEGACY_CONFIG.models.fallbackChains,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'SDK ModelPreference supports a single fallback model, not tiered chains ' +
    '(premium/standard/fast with ordered arrays). This is a BREAKING CHANGE for ' +
    'our config — we use 3 chains with 4 models each.',
});

// --- Test 4: models.defaultTier ---
results.push({
  feature: 'models.defaultTier',
  legacyValue: LEGACY_CONFIG.models.defaultTier,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'SDK has no concept of model tiers (premium/standard/fast). ' +
    'Routing rules have tier (direct/lightweight/standard/full) which is different — ' +
    'it controls ceremony level, not model selection.',
});

// --- Test 5: models.preferSameProvider ---
results.push({
  feature: 'models.preferSameProvider',
  legacyValue: LEGACY_CONFIG.models.preferSameProvider,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'No SDK equivalent. SDK model selection is explicit per-agent, ' +
    'not policy-based.',
});

// --- Test 6: models.respectTierCeiling ---
results.push({
  feature: 'models.respectTierCeiling',
  legacyValue: LEGACY_CONFIG.models.respectTierCeiling,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'No SDK equivalent. Tier ceiling concept doesn\'t exist in SDK-first mode.',
});

// --- Test 7: models.nuclearFallback ---
results.push({
  feature: 'models.nuclearFallback',
  legacyValue: LEGACY_CONFIG.models.nuclearFallback,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'No SDK equivalent. Nuclear fallback (emergency model after N retries) ' +
    'has no builder. ModelPreference has a single fallback field only.',
});

// --- Test 8: routing.rules (workType → pattern) ---
results.push({
  feature: 'routing.rules',
  legacyValue: LEGACY_CONFIG.routing.rules,
  sdkEquivalent: 'defineRouting({ rules: [...] })',
  status: '⚠️ partial',
  notes: 'Legacy uses workType + confidence; SDK uses pattern + description + tier + priority. ' +
    'workType maps to pattern, but confidence has no equivalent. ' +
    'SDK adds tier (direct/lightweight/standard/full) and priority (numeric).',
});

// --- Test 9: routing.governance ---
results.push({
  feature: 'routing.governance',
  legacyValue: LEGACY_CONFIG.routing.governance,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'No SDK equivalent for governance block (eagerByDefault, scribeAutoRuns, ' +
    'allowRecursiveSpawn). SDK routing has defaultAgent and fallback behavior but ' +
    'not these granular governance controls.',
});

// --- Test 10: casting ---
results.push({
  feature: 'casting',
  legacyValue: LEGACY_CONFIG.casting,
  sdkEquivalent: 'defineCasting()',
  status: '✅ compatible',
  notes: 'Both support allowlistUniverses, overflowStrategy, and capacity. ' +
    'Legacy uses universeCapacity, SDK uses capacity — same semantics.',
});

// --- Test 11: platforms ---
results.push({
  feature: 'platforms',
  legacyValue: LEGACY_CONFIG.platforms,
  sdkEquivalent: null,
  status: '❌ no equivalent',
  notes: 'No SDK equivalent for platform-specific overrides (vscode.disableModelSelection, ' +
    'vscode.scribeMode). The legacy PlatformOverrides type exists in runtime/config.ts ' +
    'but is not part of the SDK builder surface.',
});

// --- Test 12: SDK-only features we could gain ---
results.push({
  feature: 'team (defineTeam)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineTeam()',
  status: '🆕 sdk-only',
  notes: 'SDK requires team definition with name, description, projectContext, members. ' +
    'Our legacy config has no team block — team info lives in .squad/team.md.',
});

results.push({
  feature: 'agents (defineAgent)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineAgent()',
  status: '🆕 sdk-only',
  notes: 'SDK defines agents with role, model, tools, capabilities, charter. ' +
    'Legacy config doesn\'t define agents — they live in .squad/agents/*/charter.md.',
});

results.push({
  feature: 'ceremonies (defineCeremony)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineCeremony()',
  status: '🆕 sdk-only',
  notes: 'SDK supports ceremony definitions (standups, retros). Not in legacy schema.',
});

results.push({
  feature: 'hooks (defineHooks)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineHooks()',
  status: '🆕 sdk-only',
  notes: 'SDK supports governance hooks (allowedWritePaths, blockedCommands, scrubPii). ' +
    'Not in legacy schema.',
});

results.push({
  feature: 'telemetry (defineTelemetry)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineTelemetry()',
  status: '🆕 sdk-only',
  notes: 'SDK supports OTLP/Aspire telemetry configuration. Not in legacy schema.',
});

results.push({
  feature: 'skills (defineSkill)',
  legacyValue: 'not in legacy config',
  sdkEquivalent: 'defineSkill()',
  status: '🆕 sdk-only',
  notes: 'SDK supports skill definitions with domain, confidence, content. Not in legacy schema.',
});

// ============================================================================
// Attempt to map our legacy config to SDK-first format
// ============================================================================

let sdkConfig: SquadSDKConfig | null = null;
let migrationError: string | null = null;

try {
  sdkConfig = defineSquad({
    version: LEGACY_CONFIG.version,

    // SDK requires team — we have to create one from scratch
    team: defineTeam({
      name: 'tamresearch1',
      description: 'TAM Research squad',
      members: ['scribe'],
    }),

    // SDK requires agents — we define our scribe
    agents: [
      defineAgent({
        name: 'scribe',
        role: 'Scribe',
        description: 'Session logger and decision tracker',
        status: 'active',
      }),
    ],

    // Routing: map workType → pattern, drop confidence (no equivalent)
    routing: defineRouting({
      rules: LEGACY_CONFIG.routing.rules.map((r) => ({
        pattern: r.workType,
        agents: r.agents,
        // confidence is DROPPED — no SDK equivalent
      })),
      defaultAgent: '@scribe',
      fallback: 'coordinator',
    }),

    // Casting: maps cleanly
    casting: defineCasting({
      allowlistUniverses: LEGACY_CONFIG.casting.allowlistUniverses,
      overflowStrategy: LEGACY_CONFIG.casting.overflowStrategy as 'generic',
      capacity: LEGACY_CONFIG.casting.universeCapacity,
    }),

    // DROPPED from migration:
    //   - models.defaultModel → could use defineDefaults({ model }) but no fallback chains
    //   - models.fallbackChains → NO EQUIVALENT
    //   - models.defaultTier → NO EQUIVALENT
    //   - models.preferSameProvider → NO EQUIVALENT
    //   - models.respectTierCeiling → NO EQUIVALENT
    //   - models.nuclearFallback → NO EQUIVALENT
    //   - routing.governance → NO EQUIVALENT
    //   - platforms.vscode → NO EQUIVALENT
  });

  console.log('✅ SDK-first config created successfully (with data loss)');
} catch (err) {
  migrationError = err instanceof Error ? err.message : String(err);
  console.error('❌ SDK-first migration failed:', migrationError);
}

// ============================================================================
// Print report
// ============================================================================

console.log('\n' + '='.repeat(80));
console.log('SDK-FIRST COMPATIBILITY REPORT');
console.log('='.repeat(80));

console.log('\n## Feature Mapping\n');
for (const r of results) {
  console.log(`${r.status} ${r.feature}`);
  if (r.sdkEquivalent) console.log(`   SDK: ${r.sdkEquivalent}`);
  console.log(`   ${r.notes}`);
  console.log();
}

const compatible = results.filter((r) => r.status === '✅ compatible').length;
const partial = results.filter((r) => r.status === '⚠️ partial').length;
const noEquivalent = results.filter((r) => r.status === '❌ no equivalent').length;
const sdkOnly = results.filter((r) => r.status === '🆕 sdk-only').length;

console.log('## Summary');
console.log(`  ✅ Compatible:     ${compatible}`);
console.log(`  ⚠️  Partial:        ${partial}`);
console.log(`  ❌ No equivalent:  ${noEquivalent}`);
console.log(`  🆕 SDK-only:       ${sdkOnly}`);
console.log();

if (sdkConfig) {
  console.log('## Migration Result');
  console.log('SDK config was created but with DATA LOSS in these areas:');
  console.log('  1. models.fallbackChains (3 chains × 4 models each)');
  console.log('  2. models.defaultTier / preferSameProvider / respectTierCeiling');
  console.log('  3. models.nuclearFallback (emergency model escalation)');
  console.log('  4. routing.governance (eagerByDefault, scribeAutoRuns, allowRecursiveSpawn)');
  console.log('  5. routing.rules[].confidence ("high" field dropped)');
  console.log('  6. platforms.vscode (disableModelSelection, scribeMode)');
}

console.log('\n## Verdict');
console.log('SDK-first mode WOULD BREAK our config if it replaced the legacy format.');
console.log('The model selection system is the biggest gap — SDK has per-agent model');
console.log('preferences but no tiered fallback chains, provider affinity, or nuclear fallback.');
console.log('Governance settings and platform overrides also have no SDK-first equivalent.');
console.log('RECOMMENDATION: SDK-first should coexist with legacy, not replace it.');

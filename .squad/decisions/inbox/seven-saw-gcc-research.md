# SAW/GCC Squad Architecture Decision

**Date:** March 2025  
**Author:** Seven  
**Issue:** #504  
**PR:** #505  
**Status:** RESEARCH COMPLETE — Ready for implementation decision

---

## Decision Context

Researched feasibility of building a SAW/GCC-compatible Squad variant that can operate in Secure Admin Workstation and Government Community Cloud environments where internet access is blocked.

## Key Research Findings

1. **Azure OpenAI is Available in Gov Cloud**
   - FedRAMP High, DoD IL4/IL5/IL6 compliance
   - GPT-4o models available in usgovarizona and usgovvirginia
   - Managed Identity authentication (keyless)

2. **MCP stdio Transport is SAW-Compatible**
   - No internet or network listeners required
   - Local process communication only
   - Compatible with AppLocker/WDAC restrictions

3. **No Technical Blockers Identified**
   - All challenges are operational (binary signing, whitelisting, manual updates)
   - 3-4 week implementation timeline

## Proposed Architecture

- **Keep:** MCP stdio transport, Squad orchestration pattern, agent spawning logic
- **Change:** Replace GitHub Copilot CLI with Azure OpenAI SDK via abstraction layer
- **Add:** Azure Government-specific config (Managed Identity, .openai.azure.us endpoints)

## Team Impact

- **Picard (Lead):** Decision authority on LLM provider abstraction architecture
- **Data (Code):** Implementation of LLM provider layer and Azure OpenAI integration
- **Worf (Security):** Review WDAC policies, binary signing strategy, Managed Identity config
- **B'Elanna (Infra):** Air-gapped testing environment setup in Azure Government VNet

## Next Steps

1. Team review of research report (research/active/saw-gcc-squad/README.md)
2. Picard decides: Proceed with PoC implementation or defer
3. If approved: Data implements Phase 1 (LLM abstraction + Azure OpenAI provider)
4. Worf reviews security approach (signing, WDAC, Managed Identity)
5. B'Elanna sets up test environment in isolated Azure Government VNet

## Decision Point

**Question:** Should Squad support Azure OpenAI backend for SAW/GCC environments?

**Options:**
1. **Proceed with implementation** (3-4 weeks, moderate complexity, no blockers)
2. **Defer** (wait for customer demand signal or different approach)
3. **Investigate alternatives** (e.g., on-prem LLM deployment)

**Recommendation:** Proceed with Phase 1 PoC (1 week) to validate approach. Low risk, reversible if issues arise.

---

**For Team Discussion:** Does this align with Squad's goals? Is the SAW/GCC use case important enough to justify the effort?

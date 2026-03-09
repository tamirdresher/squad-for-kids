# Decision: Cloud Storage for Podcast Audio Files

**Date:** 2025-01-21  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #236  
**Status:** ✅ Implemented  

## Context

The Podcaster prototype (Issue #214) generates MP3 audio files from markdown documents. These audio files are large (2-56 MB per file) and were being committed to the Git repository, causing:

- **Repository bloat:** Git history grows rapidly with binary files
- **Slow operations:** Clone/pull times increase significantly
- **Poor maintainability:** Repository becomes unmanageable over time
- **Iteration overhead:** Audio regeneration creates large diffs and history noise

## Decision

**Store podcast audio files in OneDrive or Azure Blob Storage instead of Git repository.**

### Implementation Strategy

1. **Exclude audio from Git:**
   - Added `.gitignore` patterns: `*.mp3`, `*.wav`, `*-audio.mp3`, `*-audio.wav`
   - Removed existing audio files from tracking (kept on disk)

2. **Provide upload tools:**
   - Created `scripts/upload-podcast.ps1` (PowerShell, Windows-native)
   - Created `scripts/upload-podcast.py` (Python, cross-platform)
   - Both support 3 upload methods with graceful fallback

3. **Upload Methods (Priority Order):**
   - **OneDrive Sync Folder** (Default) — Simplest, no auth required
   - **Microsoft Graph API** — Proper API integration with sharing links
   - **Azure Blob Storage** — Azure-native with SAS URLs

## Rationale

### Why OneDrive Sync as Default?

**Immediate usability:** Works if OneDrive is installed and syncing (common on Microsoft machines). No authentication setup, Azure AD app registration, or Azure CLI required.

**User workflow:**
1. Generate podcast: `python scripts/podcaster-prototype.py DOCUMENT.md`
2. Upload: `.\scripts\upload-podcast.ps1 -FilePath "DOCUMENT-audio.mp3"`
3. Get sharing link: Right-click file in OneDrive → Share
4. Share with stakeholders

**Fallback options:** If OneDrive Sync fails, scripts guide users to try Graph API or Azure Blob methods.

### Why Include Graph API and Azure Blob?

- **Graph API:** Production-grade solution with programmatic sharing link generation. Ideal for automation and CI/CD pipelines.
- **Azure Blob:** Enterprise storage for teams already using Azure. Generates SAS URLs valid for 90 days.
- **Future-proofing:** Scripts are extensible; new providers can be added easily.

## Consequences

### Positive

✅ **Repository stays lean:** No audio file bloat in Git history  
✅ **Faster operations:** Clone/pull/push times remain fast  
✅ **Immediate usability:** OneDrive Sync works without setup  
✅ **Enterprise-ready:** Graph API and Azure Blob available for production  
✅ **Cross-platform:** Python script works on Windows/Mac/Linux  
✅ **Graceful degradation:** Each script suggests fallback methods  

### Negative

⚠️ **Manual step added:** Users must upload audio after generation (not automated)  
⚠️ **Sharing friction:** OneDrive Sync requires manual sharing link creation  
⚠️ **Dependency on cloud:** Requires OneDrive/Azure availability  

### Mitigation

- **Automation path:** Graph API method can be integrated into CI/CD for automatic upload and link generation
- **Clear documentation:** PODCASTER_README.md includes step-by-step instructions
- **Multiple options:** If one method fails, users have alternatives

## Alternatives Considered

### Alternative 1: Git LFS (Large File Storage)

**Pros:**
- Audio files remain in Git workflow
- Transparent to users (git add/commit/push works normally)

**Cons:**
- Requires GitHub LFS quota (bandwidth and storage costs)
- Not free at scale (50 GB bandwidth/month free, then paid)
- Still stores files in GitHub ecosystem (vendor lock-in)
- Adds complexity to repository setup

**Decision:** Rejected due to cost, quota limits, and vendor lock-in.

### Alternative 2: Azure Storage Only

**Pros:**
- Enterprise-grade storage with fine-grained access control
- Scalable to any size
- SAS tokens for time-limited sharing

**Cons:**
- Requires Azure CLI installation and authentication
- No immediate usability (setup overhead)
- Not accessible for users without Azure access

**Decision:** Rejected as primary method, but included as optional method for Azure-native teams.

### Alternative 3: Commit Small Audio Files Only

**Pros:**
- No workflow change
- Simple for users

**Cons:**
- Arbitrary size limit (what is "small"?)
- Repository still bloats over time
- Doesn't solve root problem

**Decision:** Rejected. Better to solve the problem correctly.

## Implementation Details

### Upload Scripts

Both scripts provide:
- **Progress feedback:** Console output shows upload status and errors
- **Error handling:** Clear error messages with troubleshooting guidance
- **Fallback suggestions:** If one method fails, suggests alternatives
- **Cross-platform:** PowerShell (Windows-native) and Python (universal)

### Security Considerations

- **No secrets in repo:** Graph API credentials via environment variables
- **Azure CLI auth:** Uses existing `az login` session (no embedded credentials)
- **OneDrive Sync:** Uses existing OneDrive client authentication
- **Audit trail:** Scripts log operations for compliance

### Future Enhancements

1. **Automation:** Integrate Graph API upload into podcaster script (single command)
2. **Batch upload:** Support uploading multiple files at once
3. **Link generation:** Automatically copy sharing link to clipboard
4. **CI/CD integration:** GitHub Actions workflow to upload on merge

## Monitoring and Success Metrics

- **Repository size:** Should not grow with audio file additions
- **User feedback:** Monitor ease of use and adoption
- **Upload success rate:** Track which methods are most reliable
- **Time savings:** Measure faster clone/pull operations

## References

- Issue #236: https://github.com/tamirdresher_microsoft/tamresearch1/issues/236
- PR: https://github.com/tamirdresher_microsoft/tamresearch1/pull/new/squad/236-cloud-audio-storage
- Podcaster README: `PODCASTER_README.md`
- Upload scripts: `scripts/upload-podcast.ps1`, `scripts/upload-podcast.py`

## Approval

- **Implemented by:** B'Elanna (Infrastructure Expert)
- **Date:** 2025-01-21
- **Branch:** `squad/236-cloud-audio-storage`
- **Status:** Ready for review and merge

# Bitwarden Collection-Scoped API Keys — Security Analysis

**Author:** Worf (Security & Cloud)  
**Date:** 2026-03-19  
**Related Issue:** #1036  
**Upstream:** bitwarden/server#7252  

---

## Executive Summary

Collection-scoped API keys introduce **credential isolation** at the Collection level. This analysis evaluates the security posture of the proposed implementation, identifies critical attack vectors, and defines security requirements for upstreaming to Bitwarden.

**Risk Assessment:** 🟡 MEDIUM (with proper implementation) → 🔴 HIGH (if misimplemented)

**Critical Findings:**
- ✅ SecretsManager ApiKey pattern is cryptographically sound (ClientSecretHash, not plaintext)
- 🔴 **JWT claim injection** is the primary threat — malicious collection_id claim grants unauthorized access
- 🔴 **Scope bypass** via missing Cipher filter enforcement creates lateral movement
- 🟠 **Key rotation** not addressed in current design — long-lived credentials are persistence vectors
- 🟡 **Rate limiting** required to prevent credential brute-force and API abuse

---

## 1. Threat Model

### 1.1 Adversaries

| Adversary | Capability | Motivation |
|-----------|------------|------------|
| **Malicious AI Agent** | Has valid API key for Collection A, attempts unauthorized access to Collection B | Data exfiltration, privilege escalation |
| **Compromised MCP Server** | Stolen API key from agent host machine | Credential theft, persistent backdoor access |
| **Insider Threat** | Bitwarden Organization admin abuses key management API | Credential distribution without audit trail |
| **External Attacker** | Discovers exposed API key in logs/git history | Brute-force key values, exploit weak hashing |

### 1.2 Assets Under Protection

1. **Cipher Data in Collections** — secrets, passwords, credentials stored in target Collections
2. **API Key Material** — `ClientSecret` plaintext (only at generation time), `ClientSecretHash` (persisted)
3. **JWT Claims** — `collection_id` claim determines access scope
4. **Bitwarden Organization Metadata** — Collection structure, membership, permissions

### 1.3 Trust Boundaries

```
[ AI Agent Host ]  --API Key-->  [ Bitwarden API Gateway ]
                                        |
                                        v
                              [ VaultApiKeyGrantValidator ]  <-- CRITICAL BOUNDARY
                                        |
                                        v
                                  [ JWT with collection_id claim ]
                                        |
                                        v
                              [ Cipher API Endpoints ]  <-- FILTER ENFORCEMENT REQUIRED
```

**Primary Trust Boundary:** VaultApiKeyGrantValidator → JWT issuance  
**Secondary Trust Boundary:** Cipher API → collection_id claim validation

### 1.4 Attack Scenarios

#### Scenario 1: JWT Claim Injection (🔴 CRITICAL)

**Attacker Goal:** Forge JWT with arbitrary `collection_id` claim to access unauthorized Collections.

**Attack Vector:**
1. Agent with valid API key for Collection A calls `/identity/connect/token`
2. VaultApiKeyGrantValidator issues JWT with `collection_id: <A_ID>`
3. Attacker intercepts JWT, modifies `collection_id` to `<B_ID>`, re-signs with weak/stolen key
4. Modified JWT grants access to Collection B

**Preconditions:**
- JWT signature validation disabled or weak signing algorithm (HS256 with shared secret)
- No server-side collection ownership verification during JWT issuance

**Impact:** **Complete collection isolation bypass** — one valid API key grants access to all Collections in Organization.

#### Scenario 2: Scope Bypass via Missing Cipher Filters (🔴 CRITICAL)

**Attacker Goal:** Use valid collection-scoped API key to query Ciphers outside authorized Collection.

**Attack Vector:**
1. Agent has valid API key for Collection A
2. Calls `/api/ciphers` without collection filter enforcement
3. Receives Ciphers from Collection B, C, D (all Organization Ciphers)

**Preconditions:**
- CiphersController does not validate `collection_id` JWT claim
- Cipher queries use Organization-level permissions instead of Collection-level

**Impact:** **Data exfiltration** — all Organization Ciphers leaked to collection-scoped agent.

#### Scenario 3: API Key Brute-Force (🟠 HIGH)

**Attacker Goal:** Brute-force valid API keys by exploiting weak rate limiting or predictable key generation.

**Attack Vector:**
1. Enumerate `ClientId` values (if predictable/sequential)
2. Brute-force `ClientSecret` via `/identity/connect/token` endpoint
3. No rate limiting → try millions of combinations

**Preconditions:**
- No rate limiting on `/identity/connect/token`
- Weak key entropy (< 256 bits)
- No IP-based throttling

**Impact:** **Unauthorized credential access** — attacker gains valid API key without legitimate provisioning.

#### Scenario 4: Key Leakage via Logs/Git (🟠 HIGH)

**Attacker Goal:** Discover exposed API keys in application logs, git history, or error messages.

**Attack Vector:**
1. API key logged in plaintext during generation or debug logging
2. Key committed to git repository (e.g., `.env` file, config YAML)
3. Error message reveals partial key material

**Preconditions:**
- No sanitization of API key material in logs
- Application logs stored in shared/insecure locations
- No secret scanning on git commits

**Impact:** **Credential theft** — exposed key grants persistent access until manually revoked.

#### Scenario 5: Privilege Escalation via Collection Reassignment (🟡 MEDIUM)

**Attacker Goal:** Modify Collection membership to gain access to API-key-protected Collection.

**Attack Vector:**
1. Organization admin reassigns Ciphers from Collection A → Collection B
2. Agent with API key scoped to Collection B now has unauthorized access to reassigned Ciphers

**Preconditions:**
- No audit logging of Collection membership changes
- Cipher reassignment does not invalidate existing API keys

**Impact:** **Indirect data exfiltration** — admin actions bypass collection isolation.

#### Scenario 6: Key Persistence Without Rotation (🟡 MEDIUM)

**Attacker Goal:** Use stolen API key indefinitely due to lack of rotation enforcement.

**Attack Vector:**
1. API key stolen via compromised MCP server
2. Key never expires (`ExpireAt` not set or very long duration)
3. No automated rotation mechanism

**Preconditions:**
- No max key lifetime enforcement
- No key rotation alerts or policies

**Impact:** **Persistent backdoor access** — compromised key remains valid for months/years.

---

## 2. Attack Surface Analysis

### 2.1 API Key Generation Endpoint

**Component:** `CollectionApiKeysController.CreateAsync()`

**Inputs:**
- `organizationId` (path parameter)
- `collectionId` (request body)
- `name` (request body, optional)
- `expireAt` (request body, optional)

**Attack Surface:**
- **Input validation:** Missing collectionId → IDOR (Insecure Direct Object Reference)
- **Authorization checks:** Does caller have `ManageCollectionApiKeys` permission for target Collection?
- **Rate limiting:** No max API keys per Collection → resource exhaustion
- **Entropy:** ClientSecret generation uses `SecureRandom` (good) or weak PRNG (bad)?

**Threats:**
- Unauthorized API key creation for arbitrary Collections
- Enumeration of valid Collection IDs via error messages
- API key generation spam → credential proliferation

### 2.2 VaultApiKeyGrantValidator

**Component:** `VaultApiKeyGrantValidator.ValidateAsync()`

**Inputs:**
- `client_id` (ApiKey.Id)
- `client_secret` (plaintext from agent)

**Responsibilities:**
1. Retrieve ApiKey from database by `client_id`
2. Validate `ClientSecretHash` matches `client_secret`
3. Check `ExpireAt` (if set)
4. Issue JWT with `collection_id` claim

**Attack Surface:**
- **Hash comparison timing attacks:** Use constant-time comparison
- **Database injection:** Sanitize `client_id` input
- **JWT claim tampering:** Sign JWT with strong asymmetric key (RS256/ES256)
- **No revocation check:** Stolen keys remain valid until expiry

**Threats:**
- Timing oracle reveals valid `client_id` values
- SQL injection via malicious `client_id`
- JWT signature bypass → claim forgery

### 2.3 Cipher API Endpoints

**Component:** `CiphersController.Get()`, `CiphersController.GetByOrganization()`

**Responsibilities:**
- Extract `collection_id` from JWT claims
- Filter Cipher queries to only return Ciphers in authorized Collection

**Attack Surface:**
- **Missing claim validation:** No `collection_id` claim → fallback to Organization-level access
- **IDOR:** API accepts `collectionId` query parameter that overrides JWT claim
- **Pagination bypass:** Unauthenticated endpoint returns all Ciphers

**Threats:**
- Scope bypass — all Organization Ciphers leaked
- IDOR via query parameter injection

### 2.4 Data Model & Database

**Component:** `ApiKey` entity, `ApiKeyRepository`, SQL migrations

**Attack Surface:**
- **FK constraint missing:** ApiKey.CollectionId references non-existent Collection → orphaned keys
- **No unique constraint:** Multiple API keys with same `ClientId` → hash collision exploitation
- **No audit trail:** Key creation/deletion not logged → forensic blind spots

**Threats:**
- Orphaned API keys grant access to deleted Collections
- Key collision enables credential reuse

---

## 3. Auth Flow Security Review

### 3.1 Current SecretsManager ApiKey Pattern

```csharp
// Good: Hash comparison uses SecureCompare (constant-time)
if (!CoreHelpers.SecureCompare(clientSecretHash, apiKey.ClientSecretHash))
{
    return null;
}

// Good: ExpireAt validation
if (apiKey.ExpireAt.HasValue && apiKey.ExpireAt.Value < DateTime.UtcNow)
{
    return null;
}
```

**✅ Strengths:**
- ClientSecretHash stored, not plaintext
- Constant-time hash comparison prevents timing attacks
- Expiration enforcement (if set)

**🔴 Gaps for Collection-Scoped Keys:**
- No `collection_id` validation during JWT issuance
- No revocation status check
- No audit logging of auth attempts

### 3.2 Proposed Collection-Scoped Flow

**Step 1:** Agent calls `/identity/connect/token` with `client_id` and `client_secret`

```http
POST /identity/connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=vault_api_key&
client_id=<API_KEY_ID>&
client_secret=<API_KEY_SECRET>
```

**Step 2:** VaultApiKeyGrantValidator validates credentials

```csharp
var apiKey = await _apiKeyRepository.GetByIdAsync(clientId);
if (apiKey == null) return null;

// REQUIRED: Verify CollectionId exists and is active
var collection = await _collectionRepository.GetByIdAsync(apiKey.CollectionId);
if (collection == null || collection.IsDeleted) return null;

// REQUIRED: Hash comparison
if (!CoreHelpers.SecureCompare(clientSecretHash, apiKey.ClientSecretHash))
{
    return null;
}

// REQUIRED: Expiration check
if (apiKey.ExpireAt.HasValue && apiKey.ExpireAt.Value < DateTime.UtcNow)
{
    return null;
}

// REQUIRED: Check revocation status (future feature)
// if (apiKey.IsRevoked) return null;
```

**Step 3:** Issue JWT with `collection_id` claim

```json
{
  "sub": "<API_KEY_ID>",
  "collection_id": "<COLLECTION_UUID>",
  "org_id": "<ORGANIZATION_UUID>",
  "scope": "vault.api",
  "iat": 1710888000,
  "exp": 1710891600
}
```

**🔴 CRITICAL REQUIREMENTS:**
1. **RS256/ES256 signature** — no shared secrets (HS256)
2. **Short-lived tokens** — max 1 hour expiration
3. **Audience validation** — `aud: "vault.bitwarden.com"`
4. **Issuer validation** — `iss: "identity.bitwarden.com"`

**Step 4:** Cipher API validates `collection_id` claim

```csharp
// CiphersController.cs
[Authorize(Policy = Policies.VaultApi)]
public async Task<ListResponseModel<CipherMiniDetailsResponseModel>> Get()
{
    var collectionId = _currentContext.GetCollectionId(); // Extract from JWT
    if (collectionId == null)
    {
        throw new UnauthorizedAccessException("Missing collection_id claim");
    }

    // REQUIRED: Filter by Collection
    var ciphers = await _cipherRepository.GetManyByCollectionIdAsync(collectionId.Value);
    return new ListResponseModel<CipherMiniDetailsResponseModel>(ciphers);
}
```

**🔴 CRITICAL REQUIREMENTS:**
1. **Mandatory claim validation** — reject requests without `collection_id`
2. **No fallback to Organization-level** — fail closed, not open
3. **Query parameter rejection** — ignore `?collectionId=` override attempts
4. **Pagination enforcement** — apply filter to all pages

### 3.3 JWT Security Checklist

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Asymmetric signing (RS256/ES256) | 🔴 REQUIRED | Use organization-specific RSA key pair |
| Short-lived tokens (≤ 1 hour) | 🔴 REQUIRED | Set `exp` claim to `iat + 3600` |
| Audience validation | 🟠 RECOMMENDED | `aud: "vault.bitwarden.com"` |
| Issuer validation | 🟠 RECOMMENDED | `iss: "identity.bitwarden.com"` |
| No sensitive data in claims | ✅ SATISFIED | Only UUIDs, no secrets |
| JTI (JWT ID) for revocation | 🟡 OPTIONAL | Enables per-token revocation |

---

## 4. Cryptographic Requirements

### 4.1 API Key Generation

**Requirement:** `ClientSecret` must have **≥ 256 bits entropy** (cryptographically random).

**Implementation:**
```csharp
// CORRECT: Use SecureRandom
var clientSecret = CoreHelpers.SecureRandomString(32, upper: true, lower: true, numeric: true, special: false);
// Generates 32-character alphanumeric → 190 bits entropy (5.95 bits/char)

// BETTER: Use full byte randomness
var clientSecretBytes = new byte[32]; // 256 bits
RandomNumberGenerator.Fill(clientSecretBytes);
var clientSecret = Convert.ToBase64String(clientSecretBytes); // URL-safe encoding
```

**🔴 CRITICAL:** Never use `Random()`, `Guid.NewGuid()`, or timestamp-based generation.

### 4.2 API Key Hashing

**Requirement:** `ClientSecretHash` must use **slow, salted hash** (not SHA256 alone).

**Current SecretsManager Implementation:**
```csharp
// CRITICAL: What algorithm is SecretHasher using?
apiKey.ClientSecretHash = _secretHasher.Hash(clientSecret);
```

**Required Algorithm:** **bcrypt** (cost factor 12+) or **PBKDF2** (100k+ iterations)

**🔴 DANGEROUS IF:**
- SecretHasher uses SHA256/SHA512 without salt → rainbow table attack
- SecretHasher uses MD5/SHA1 → collision attacks

**Verification Required:** Inspect `SecretHasher` implementation in `src/Core/Services/SecretHasher.cs`.

### 4.3 Hash Comparison

**Requirement:** **Constant-time comparison** to prevent timing attacks.

**Current Implementation:**
```csharp
CoreHelpers.SecureCompare(clientSecretHash, apiKey.ClientSecretHash)
```

**✅ GOOD:** Uses constant-time comparison (verified in SecretsManager).

### 4.4 JWT Signing

**Requirement:** **Asymmetric signing** (RS256 or ES256) with organization-specific key pairs.

**🔴 DANGEROUS:**
```csharp
// BAD: Shared secret across all organizations
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("shared_secret"));
var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
```

**✅ CORRECT:**
```csharp
// GOOD: Per-organization RSA key pair
var rsa = RSA.Create(2048);
var key = new RsaSecurityKey(rsa);
var creds = new SigningCredentials(key, SecurityAlgorithms.RsaSha256);
```

**Key Storage:** Store private keys in **Azure Key Vault** or **Hardware Security Module (HSM)**, not filesystem.

---

## 5. Rate Limiting & Abuse Prevention

### 5.1 API Key Generation Limits

**Threat:** Attacker creates unlimited API keys to proliferate credentials or exhaust storage.

**Mitigations:**
1. **Per-Collection limit:** Max 50 API keys per Collection
2. **Per-Organization limit:** Max 500 API keys per Organization
3. **Rate limiting:** Max 10 key creations per hour per Organization
4. **CAPTCHA:** Require CAPTCHA for key generation via web UI

**Implementation:**
```csharp
// CollectionApiKeysController.cs
var existingKeys = await _apiKeyRepository.GetManyByCollectionIdAsync(collectionId);
if (existingKeys.Count >= 50)
{
    throw new BadRequestException("Collection API key limit exceeded (max 50)");
}
```

### 5.2 Auth Endpoint Rate Limiting

**Threat:** Brute-force attack on `/identity/connect/token` to guess valid API keys.

**Mitigations:**
1. **IP-based throttling:** Max 100 requests/hour per IP
2. **Key-based throttling:** Max 10 failed attempts per `client_id` → 1-hour lockout
3. **Exponential backoff:** Increase delay after each failed attempt

**Implementation:**
```csharp
// VaultApiKeyGrantValidator.cs
var failedAttempts = await _cache.GetAsync($"failed_auth:{clientId}");
if (failedAttempts >= 10)
{
    throw new RateLimitException("API key locked due to repeated failed attempts");
}
```

### 5.3 Cipher Query Rate Limiting

**Threat:** API key used for mass data exfiltration via repeated Cipher queries.

**Mitigations:**
1. **Per-key throttling:** Max 1000 Cipher queries per hour per API key
2. **Pagination limits:** Max 1000 Ciphers per query response
3. **Anomaly detection:** Alert on > 10,000 Cipher accesses per day per key

**Implementation:**
```csharp
// CiphersController.cs
var queryCount = await _cache.IncrementAsync($"cipher_queries:{apiKeyId}", expiry: TimeSpan.FromHours(1));
if (queryCount > 1000)
{
    throw new RateLimitException("API key query limit exceeded");
}
```

---

## 6. Audit Logging Requirements

### 6.1 Security Events to Log

| Event | Fields | Retention |
|-------|--------|-----------|
| API key created | `organizationId`, `collectionId`, `createdBy`, `timestamp`, `keyId` | 2 years |
| API key deleted | `organizationId`, `collectionId`, `deletedBy`, `timestamp`, `keyId` | 2 years |
| Auth attempt (success) | `keyId`, `collectionId`, `timestamp`, `ipAddress`, `userAgent` | 90 days |
| Auth attempt (failure) | `keyId` (if provided), `timestamp`, `ipAddress`, `failureReason` | 90 days |
| Cipher accessed via API | `keyId`, `collectionId`, `cipherId`, `timestamp`, `ipAddress` | 90 days |
| Rate limit exceeded | `keyId`, `endpoint`, `timestamp`, `ipAddress` | 90 days |
| JWT issued | `keyId`, `collectionId`, `timestamp`, `tokenExpiry` | 90 days |

### 6.2 Audit Log Access Controls

**Requirement:** Only Organization **Owners** and **Admins** can view audit logs.

**Implementation:**
```csharp
[Authorize(Policy = Policies.OrganizationAdmin)]
public async Task<ListResponseModel<AuditLogEntryResponseModel>> GetAuditLogs(Guid organizationId)
{
    var logs = await _auditLogRepository.GetByOrganizationIdAsync(organizationId);
    return new ListResponseModel<AuditLogEntryResponseModel>(logs);
}
```

### 6.3 Alerting on Suspicious Activity

**Triggers:**
1. **10+ failed auth attempts** for same `client_id` within 1 hour → email Organization Owner
2. **API key used from > 5 different IPs** within 24 hours → potential key leakage
3. **> 10,000 Cipher accesses** per day per key → data exfiltration alert

---

## 7. Security Testing Strategy

### 7.1 Unit Tests

**Coverage Required:**
- VaultApiKeyGrantValidator correctly rejects expired keys
- VaultApiKeyGrantValidator correctly rejects invalid ClientSecret
- CiphersController filters by collection_id claim
- Hash comparison uses constant-time algorithm
- API key generation enforces entropy requirements

**Test Cases:**
```csharp
[Test]
public async Task VaultApiKeyGrantValidator_RejectsExpiredKey()
{
    var expiredKey = new ApiKey { ExpireAt = DateTime.UtcNow.AddDays(-1) };
    var result = await _validator.ValidateAsync(expiredKey);
    Assert.IsNull(result);
}

[Test]
public async Task CiphersController_FiltersBy CollectionId()
{
    var collectionId = Guid.NewGuid();
    _currentContext.Setup(x => x.GetCollectionId()).Returns(collectionId);
    var ciphers = await _controller.Get();
    Assert.All(ciphers.Data, c => Assert.Equal(collectionId, c.CollectionId));
}
```

### 7.2 Integration Tests

**Scenarios:**
1. End-to-end auth flow: Generate API key → authenticate → query Ciphers → verify filtering
2. Unauthorized access: API key for Collection A → attempt to access Collection B → expect 403
3. Expired key rejection: Generate key with `ExpireAt` in past → expect 401
4. Rate limiting: Exceed auth attempts → expect 429

### 7.3 Penetration Testing

**Manual Test Plan:**
1. **JWT claim tampering:** Intercept JWT, modify `collection_id`, replay → verify rejection
2. **IDOR:** Call Cipher API with `?collectionId=<OTHER_COLLECTION>` query parameter → verify ignored
3. **Brute-force:** Attempt 1000 auth requests with invalid `client_secret` → verify lockout
4. **Timing attack:** Measure response time for valid vs. invalid `client_id` → verify constant-time
5. **Key leakage:** Inspect logs, error messages, database for plaintext `ClientSecret` → verify hashed
6. **Privilege escalation:** Create API key as non-admin → verify permission denied
7. **Scope bypass:** Use SecretsManager API key to access Vault Ciphers → verify rejection

### 7.4 Fuzzing

**Targets:**
- `/identity/connect/token` with malformed `client_id`, `client_secret`
- Cipher API endpoints with SQL injection payloads in JWT claims
- API key generation endpoint with long strings, special characters

**Tools:**
- **OWASP ZAP** — automated web vulnerability scanner
- **Burp Suite** — manual fuzzing with Intruder
- **SQLMap** — SQL injection detection

### 7.5 Static Analysis

**Tools:**
- **SonarQube** — detect hardcoded secrets, weak crypto, SQL injection
- **Snyk** — dependency vulnerability scanning
- **Semgrep** — custom rules for Bitwarden-specific patterns

**Custom Rules:**
```yaml
# Detect hardcoded API keys
rules:
  - id: hardcoded-api-key
    pattern: |
      var clientSecret = "..."
    message: "Hardcoded API key detected"
    severity: ERROR
```

---

## 8. Implementation Security Checklist

### 8.1 Data Model

- [ ] `ApiKey.CollectionId` is non-nullable UUID
- [ ] Foreign key constraint: `ApiKey.CollectionId` → `Collection.Id` with `ON DELETE CASCADE`
- [ ] Unique constraint: `(ClientId)` to prevent collisions
- [ ] Index on `CollectionId` for efficient queries
- [ ] `ClientSecretHash` uses bcrypt/PBKDF2 (≥ 100k iterations)
- [ ] `ClientSecret` plaintext never persisted to database

### 8.2 Auth Flow

- [ ] VaultApiKeyGrantValidator validates `CollectionId` exists and is active
- [ ] Constant-time hash comparison (`CoreHelpers.SecureCompare`)
- [ ] JWT signed with RS256/ES256 (not HS256)
- [ ] JWT includes `collection_id`, `org_id`, `scope`, `exp`, `aud`, `iss` claims
- [ ] JWT expiration ≤ 1 hour
- [ ] No fallback to Organization-level access if `collection_id` missing

### 8.3 API Endpoints

- [ ] `CiphersController` extracts `collection_id` from JWT claims (not query params)
- [ ] All Cipher queries filter by `collection_id`
- [ ] Unauthorized Collection access returns 403 Forbidden
- [ ] Missing `collection_id` claim returns 401 Unauthorized
- [ ] API key generation requires `ManageCollectionApiKeys` permission
- [ ] API key creation enforces per-Collection limit (max 50)

### 8.4 Rate Limiting

- [ ] IP-based throttling on `/identity/connect/token` (100 req/hour)
- [ ] Key-based lockout after 10 failed auth attempts (1 hour)
- [ ] Cipher query throttling (1000 req/hour per key)
- [ ] API key creation throttling (10 req/hour per Organization)

### 8.5 Audit Logging

- [ ] Log API key creation (organizationId, collectionId, createdBy, timestamp)
- [ ] Log API key deletion (organizationId, collectionId, deletedBy, timestamp)
- [ ] Log auth attempts (success and failure, with IP address)
- [ ] Log Cipher accesses via API key (keyId, collectionId, cipherId, timestamp)
- [ ] Audit logs retained for 90 days (auth/access) and 2 years (key lifecycle)

### 8.6 Testing

- [ ] Unit tests for VaultApiKeyGrantValidator (expired keys, invalid secrets)
- [ ] Unit tests for CiphersController (collection filtering, IDOR prevention)
- [ ] Integration tests for end-to-end auth flow
- [ ] Penetration tests for JWT tampering, IDOR, brute-force
- [ ] Fuzzing on auth endpoint and Cipher API
- [ ] Static analysis with SonarQube, Snyk, Semgrep

---

## 9. Threat Mitigation Summary

| Threat | Severity | Mitigation | Status |
|--------|----------|------------|--------|
| JWT claim injection | 🔴 CRITICAL | RS256 signing, claim validation, no HS256 | 🔴 REQUIRED |
| Scope bypass (missing filters) | 🔴 CRITICAL | Mandatory `collection_id` filter on all Cipher queries | 🔴 REQUIRED |
| API key brute-force | 🟠 HIGH | IP throttling, key lockout, exponential backoff | 🔴 REQUIRED |
| Key leakage via logs | 🟠 HIGH | Never log `ClientSecret`, hash before storage | 🔴 REQUIRED |
| Privilege escalation (Collection reassignment) | 🟡 MEDIUM | Audit logging of Collection changes | 🟠 RECOMMENDED |
| Persistent key without rotation | 🟡 MEDIUM | Enforce max key lifetime, rotation alerts | 🟡 OPTIONAL |

---

## 10. Recommendations for Upstream PR

### 10.1 Must-Have for Initial PR

1. **RS256 JWT signing** — no shared secrets
2. **Mandatory collection_id claim validation** — fail closed
3. **Constant-time hash comparison** — prevent timing attacks
4. **Per-Collection API key limits** — max 50 keys per Collection
5. **Audit logging** — key lifecycle + auth attempts
6. **Unit tests** — 80%+ coverage on security-critical paths

### 10.2 Should-Have for Production Readiness

1. **Rate limiting** — IP and key-based throttling
2. **Key expiration enforcement** — default 90-day max lifetime
3. **Penetration testing** — JWT tampering, IDOR, brute-force
4. **Anomaly detection** — alert on suspicious activity
5. **Revocation API** — manual key invalidation endpoint

### 10.3 Nice-to-Have for Future Enhancements

1. **Automated key rotation** — scheduled rotation with notification
2. **JTI-based revocation** — per-token revocation
3. **IP whitelisting** — restrict API key to specific IPs/CIDR ranges
4. **Webhook notifications** — alert on key creation/deletion/usage
5. **Key usage analytics** — dashboard for key activity

---

## 11. Appendix: Glossary

- **IDOR (Insecure Direct Object Reference):** Vulnerability where attacker manipulates ID parameters to access unauthorized resources
- **JWT (JSON Web Token):** Compact token format for authentication/authorization claims
- **RS256:** RSA signature with SHA-256 (asymmetric algorithm)
- **HS256:** HMAC signature with SHA-256 (symmetric algorithm, less secure)
- **bcrypt:** Password hashing algorithm with configurable cost factor (slow by design)
- **PBKDF2:** Password-Based Key Derivation Function 2 (slow hash with salt and iterations)
- **Rainbow table:** Precomputed hash lookup table for password cracking
- **Timing attack:** Exploit that infers secrets by measuring response time differences
- **Rate limiting:** Throttling mechanism to prevent abuse by limiting request frequency

---

## 12. References

- Bitwarden SecretsManager Architecture: `bitwarden/server/src/Core/SecretsManager/`
- OWASP API Security Top 10: https://owasp.org/API-Security/
- NIST Password Guidelines (SP 800-63B): https://pages.nist.gov/800-63-3/
- JWT Best Practices (RFC 8725): https://datatracker.ietf.org/doc/html/rfc8725
- Timing Attack Defenses: https://codahale.com/a-lesson-in-timing-attacks/

---

**Next Steps:**
1. Review with Picard (Lead) — prioritize implementation phases
2. Fork bitwarden/server and begin Phase 1 implementation
3. Schedule penetration testing before upstream PR submission
4. Coordinate with Bitwarden security team for threat model review

**Status:** ✅ Security analysis complete. Ready for implementation.

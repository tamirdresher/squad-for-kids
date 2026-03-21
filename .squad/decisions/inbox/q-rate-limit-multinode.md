# Decision: Rate Governor Multi-Node Architecture Guidance

**Date:** 2026-03-21  
**Agent:** Q (Devil's Advocate & Fact Checker)  
**Issue:** #1281  
**Status:** Recommendation

---

## Context

The blog post about the Rate Governor for multi-agent systems describes a file-based Rate State Store:
- `rate-pool.json` — shared token pool
- `rate-state.json` — coordination state
- File locking for mutual exclusion
- Heartbeat files for lease-based cleanup

The blog states: "No central server needed — it's cooperative coordination through the filesystem."

Tamir raised the concern: **This only works on same machine or shared filesystem with strong semantics. What about multi-machine K8s deployments?**

---

## Finding

✅ **Tamir's concern is valid.** The file-based approach is:
- ✅ **Proven and battle-tested** for single-node deployments
- ⚠️ **Requires careful PVC configuration** for multi-pod K8s (ReadWriteMany + strong consistency)
- ❌ **Has known limitations** for distributed coordination (file locking semantics, heartbeat propagation delays, no fencing tokens)

---

## Decision / Recommendation

### For Blog Post:
1. **Explicitly scope to single-node** in the architecture introduction
2. **Add "Multi-Node Considerations" section** documenting:
   - What works out-of-box (single machine, Azure Files Premium PVC)
   - Known gaps (file locking atomicity, heartbeat propagation, race conditions)
   - Production-grade distributed options (Redis, etcd, Azure NetApp Files)

### For Future Implementation:
When Squad scales beyond single-node, **migrate to Redis** for the shared state store:
- Atomic operations (DECRBY) for token allocation
- Built-in distributed locking (or use Redlock pattern)
- Lease management with auto-expiry (SET key EX)
- Azure Cache for Redis provides managed service with 99.9% SLA

**Do NOT use:**
- ConfigMaps for high-frequency updates (etcd bottleneck)
- Standard Azure Files without strong consistency tier
- EmptyDir or HostPath volumes for cross-pod coordination

---

## Technical Details

### File-Based Limitations in K8s:

| Issue | Impact | Mitigation |
|-------|--------|------------|
| File locking not atomic on NFS/SMB | Race conditions in token allocation | Use Azure NetApp Files (POSIX-compliant) or migrate to Redis |
| Heartbeat file propagation delay | False "dead pod" detection, token reclaim errors | Use Redis with SET key EX for atomic lease expiry |
| No fencing tokens | Network-partitioned pod can corrupt state | Use etcd/Consul with distributed lock primitives |
| K8s volume type confusion | EmptyDir = per-pod, no sharing | Document required PVC type (ReadWriteMany + Azure Files Premium) |

### Redis Alternative (Recommended for Scale):

```powershell
# Atomic token allocation with Redis
function Allocate-Tokens {
    param([int]$Count)
    $redis = Connect-Redis -Endpoint "squad-pool.redis.cache.windows.net"
    $available = Invoke-RedisCommand -Redis $redis -Command "DECRBY" -Args @("rate-pool:tokens", $Count)
    if ($available -lt 0) {
        Invoke-RedisCommand -Redis $redis -Command "INCRBY" -Args @("rate-pool:tokens", $Count)
        return $null  # Allocation failed
    }
    return $available
}

# Heartbeat lease with auto-expiry
Invoke-RedisCommand -Redis $redis -Command "SET" -Args @("heartbeat:ralph", "alive", "EX", 10, "NX")
```

**Azure Integration:** Use Azure Cache for Redis (Basic tier = $15/mo, Standard tier = $55/mo for HA).

---

## Related Context

**Pattern 1 (Traffic Light Throttling) Issue:**
- Blog claims parsing `x-ratelimit-remaining` from `gh copilot -p` responses
- **Reality:** `gh copilot -p` does NOT expose headers
- Actual implementation uses reactive 429 detection + log parsing
- Recommendation: Clarify Pattern 1 applies to `gh api` (which has headers), not `gh copilot -p`

---

## Next Steps

1. ✅ Q posted analysis to issue #1281
2. ⏳ Pending: Troi/Data revise blog post with multi-node section
3. ⏳ Pending: If Squad scales to multi-pod K8s, prototype Redis integration

---

**Confidence:** ✅ High  
**Reviewed by:** Tamir Dresher (project owner)  
**References:**
- [K8s Volume Types](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Azure Files Consistency](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-introduction)
- [Redis Distributed Locks](https://redis.io/docs/manual/patterns/distributed-locks/)
- [Azure Cache for Redis](https://azure.microsoft.com/en-us/products/cache/)

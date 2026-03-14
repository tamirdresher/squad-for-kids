# Azure GPU Options for Voice Cloning (F5-TTS / XTTS)

**Author:** B'Elanna (Infrastructure)  
**Date:** 2025-07-17  
**Requested by:** Tamir Dresher  
**Subscription:** WCD_MicroServices_Staging_LBI (`c5d1c552-a815-4fc8-b12d-ab444e3225b1`)

---

## TL;DR

**No usable GPU quota exists** in this subscription across any Azure region. All modern GPU VM families (T4, A10, A100, H100) have **0 quota** in every region checked. Legacy NC/NV families have residual quota but those VM SKUs are retired. However, **Azure ML has a separate 100 vCPU quota** for legacy NC/NV compute clusters that may be worth investigating.

---

## 1. VM GPU Quota Scan — All Regions

### Regions checked (14 total)
eastus, westus2, westeurope, northeurope, southcentralus, canadacentral, uksouth, australiaeast, eastus2, centralus, japaneast, koreacentral, francecentral, switzerlandnorth, swedencentral

### Results — Modern GPU Families (ALL ZERO everywhere)

| Family | Description | Quota (all regions) |
|--------|------------|---------------------|
| Standard NCASv3_T4 | NVIDIA T4 (cheapest ML GPU) | **0** |
| Standard NCADSA10v4 | NVIDIA A10 | **0** |
| Standard NVADSA10v5 | NVIDIA A10 (NV-series) | **0** |
| Standard NCSv3 | NVIDIA V100 | **0** |
| Standard NCSv2 | NVIDIA P100 | **0** |
| Standard NCADS_A100_v4 | NVIDIA A100 | **0** |
| Standard NCadsH100v5 | NVIDIA H100 | **0** |
| Standard NVSv3 | NVIDIA M60 | **0** |
| Standard NVSv4 | AMD MI25 | **0** |

### Legacy Families — Non-zero but RETIRED

| Family | Quota | Status |
|--------|-------|--------|
| Standard NC Family (K80) | 48 vCPUs | ⚠️ **Retired Sept 2023** — cannot deploy |
| Standard NC Promo (K80) | 48 vCPUs | ⚠️ **Retired** |
| Standard NV Family (M60) | 24 vCPUs | ⚠️ **Retired** |
| Standard NV Promo (M60) | 24 vCPUs | ⚠️ **Retired** |

All legacy quotas show 0 current usage / non-zero limit, but the underlying VM SKUs have been decommissioned.

---

## 2. Azure ML — Separate GPU Quota (PROMISING LEAD)

### Existing Workspaces

| Workspace | Location | Kind |
|-----------|----------|------|
| dk8s-ai-hub | eastus | Hub |
| hack-llm | eastus | Project |
| tamir-ml | eastus | Default |
| tamir-ml2 | eastus | Default |
| tamirdresher-5835_ai | eastus2 | Hub |
| tamirdresher-semantickernel | eastus2 | Project |
| mtpsov-ai-foundry | eastus2 | Hub |
| mtpsov-ml | eastus2 | Default |

### Azure ML Compute Quota (eastus) — DIFFERENT from VM quota!

| Family | Used | Limit | Notes |
|--------|------|-------|-------|
| **Standard NC Family Cluster** | 0 | **100** | ⚠️ Legacy K80 — may still work in ML context |
| **Standard NV Family Cluster** | 0 | **100** | ⚠️ Legacy M60 — may still work in ML context |
| Standard NCSv3 | 0 | 0 | V100 — no quota |
| Standard NCASv3_T4 | 0 | 0 | T4 — no quota |
| Standard NCADSA100v4 | 0 | 0 | A100 — no quota |
| Low Priority (all families) | 0 | -1 | Potentially unlimited spot instances |

**Key Insight:** Azure ML has its own quota system. The 100 vCPU limit for NC/NV compute clusters is separate from the VM-level quota. Even though the original NC/NV VMs are retired for IaaS, Azure ML compute clusters **may** still provision them. Worth testing — create a compute instance in `tamir-ml` workspace with `Standard_NC6` size.

---

## 3. Azure Container Instances (ACI)

ACI GPU support is limited to specific regions (westus2, eastus, westeurope, southeastasia) and SKUs (K80, P100, T4, V100). However, ACI GPU requires separate quota approval and our subscription shows no existing GPU containers. The GPU container instance capability requires an explicit quota request.

---

## 4. Azure Batch

- **Account quota:** 3 accounts allowed (none exist)
- Azure Batch could provide GPU compute via low-priority/spot VMs
- However, Batch uses the same underlying VM quotas, so modern GPU families would still be 0
- May work with dedicated Batch pools if legacy NC quota is active in Batch context

---

## 5. Recommended Actions (Prioritized)

### 🟢 Option A: Try Azure ML Compute Instance (NC6) — Fastest path
The `tamir-ml` workspace has 100 vCPU NC Family quota. Try creating a compute instance:
```bash
# Using Azure Portal or CLI (once az ml extension works):
az ml compute create --name xtts-gpu \
  --workspace-name tamir-ml \
  --resource-group <rg-of-tamir-ml> \
  --type ComputeInstance \
  --size Standard_NC6 \
  --location eastus
```
If this works, you get a K80 GPU with 12GB VRAM — enough for XTTS v2 inference.

### 🟡 Option B: Request GPU Quota Increase — 1-3 business days
Request quota for `Standard NCASv3_T4 Family` (cheapest modern GPU):
- **URL:** https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas
- **Steps:**
  1. Go to Azure Portal → Quotas → Compute
  2. Filter by subscription `WCD_MicroServices_Staging_LBI`
  3. Search for `NCASv3_T4`
  4. Click "Request quota increase"
  5. Request 4 vCPUs (enough for NC4as_T4_v3, cheapest T4 VM)
  6. Region: eastus or westus2
  7. Justification: "AI/ML voice synthesis research — need T4 GPU for inference only"

### 🟡 Option C: XTTS v2 on CPU (DevBox) — Works now, slower
Coqui XTTS v2 supports CPU inference. It's ~10-20x slower than GPU but functional.
- The DevBox (TAMIRDRESHER1) has Python 3.12
- Expected: ~30-60 seconds per sentence on CPU vs ~2-3 seconds on GPU
- See GitHub issue for step-by-step instructions
- **Created:** GitHub issue "Run XTTS voice cloning on DevBox CPU"

### 🟠 Option D: GitHub Codespaces with GPU
- GitHub Codespaces offers GPU-enabled machines (up to NVIDIA T4)
- Requires organization-level enable: Settings → Codespaces → Machine types → Enable GPU
- Cost: ~$1.80/hour for 4-core GPU machine
- **Limitation:** Requires GitHub Enterprise or org-level approval

### 🟠 Option E: Azure DevBox with GPU SKU
- Azure DevBox supports GPU SKUs for dev workstations
- Available GPU SKUs: `general_a_8c32gb_v2` (AMD GPU for rendering, NOT suitable for ML)
- **Not recommended** for ML workloads — DevBox GPUs are for graphics/rendering, not CUDA compute

### 🔴 Option F: External GPU Cloud (last resort)
- RunPod.io: ~$0.39/hour for T4, instant provisioning
- Lambda Cloud: ~$0.50/hour for A10
- Google Colab Pro: $10/month, includes T4 GPU
- **Risk:** Data leaves Azure boundary; check compliance requirements

---

## 6. XTTS v2 Hardware Requirements

| Mode | Min VRAM | Min RAM | Approx Speed |
|------|----------|---------|-------------|
| GPU (T4) | 4 GB | 8 GB | ~2-3 sec/sentence |
| GPU (K80) | 12 GB | 8 GB | ~5-8 sec/sentence |
| CPU only | N/A | 16 GB | ~30-60 sec/sentence |

XTTS v2 model size: ~1.8 GB. Works on CPU with `device="cpu"` flag.

---

## 7. F5-TTS Considerations

F5-TTS is GPU-only (no CPU fallback). If GPU access is obtained:
```bash
pip install f5-tts
f5-tts_infer-cli --model F5-TTS --ref_audio voice_samples/dotan_ref.wav \
  --ref_text "reference text" --gen_text "שלום עולם" --output test_f5.wav
```
Requires ~6 GB VRAM minimum. T4 (16 GB) or K80 (12 GB) would work.

---

## Decision Needed

@tamir — Please decide:
1. **Try Azure ML NC6 compute** (I can attempt this immediately)
2. **Submit quota request** for T4 (takes 1-3 days)
3. **Go CPU-first** on DevBox with XTTS v2 (issue created)
4. **Multiple paths** — start CPU on DevBox AND request T4 quota in parallel

My recommendation: **Option 4** — Start with CPU on DevBox for immediate results, while requesting T4 quota for better quality/speed later.

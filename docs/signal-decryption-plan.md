# Signal E2E Decryption — Integration Guide

> Relates to: [Issue #1052](../../issues/1052)
> Branch: `squad/1052-signal-decryption-TAMIRDRESHER`

## Overview

This document describes the Signal protocol decryption layer added to `wa-monitor-dotnet`
and explains how to wire it into the WhatsApp WebSocket message handler.

## New Files

| File | Purpose |
|------|---------|
| `Protocol/DeviceStore.cs` | Long-term Curve25519 key storage (identity, signed pre-key, noise). JSON-persisted under `~/.whatsapp-monitor/session-data/`. |
| `Protocol/SignalProtocolStoreImpl.cs` | File-backed `SignalProtocolStore`. Stores sessions, pre-keys, signed pre-keys, and trusted identities under `~/.whatsapp-monitor/signal-sessions/`. |
| `Protocol/PreKeyManager.cs` | One-time pre-key pool. Sequential IDs prevent pool-mismatch when WA requests a specific key. Counter persisted in `next-prekey-id.txt`. |
| `Protocol/MessageDecryptor.cs` | Decrypts `pkmsg` / `msg` / `skmsg` enc frames. Strips WA's PKCS#7 padding after decryption. |
| `Protocol/WaMessageParser.cs` | Hand-rolled protobuf reader for `WAWebProtobufsE2E.Message`. |
| `Protocol/SignalDecryptionService.cs` | High-level façade. Entry point for application code. |

## Architecture

```
WebSocket frame
  └─ enc node { type, ciphertext, senderKeyDistributionMessage? }
       │
       ▼
SignalDecryptionService.DecryptEncNode(jid, deviceId, encType, ciphertext)
  ├─ pkmsg  ──► SessionCipher.decrypt(PreKeySignalMessage)
  ├─ msg    ──► SessionCipher.decrypt(SignalMessage)
  └─ skmsg  ──► GroupCipher.decrypt(SenderKeyMessage)
                   (requires prior SenderKeyDistribution registration)
       │
       ▼
  PKCS#7 unpad
       │
       ▼
WaMessageParser.Parse(plaintext)
  └─ WaDecryptedMessage { MessageType, Conversation, ... }
```

## Integration Steps

### 1. Bootstrap on startup

```csharp
var decryptionService = new SignalDecryptionService(loggerFactory);
await decryptionService.EnsurePreKeyPool();   // generates 100 one-time pre-keys if pool is empty
```

### 2. Register pre-keys with WhatsApp

After pairing, upload the pre-key bundle to WhatsApp's registration endpoint:

```csharp
var (device, store, pkManager) = decryptionService.GetComponents();
var preKeys       = pkManager.GenerateBatch(30);   // upload ~30 at registration
var signedPreKey  = pkManager.GenerateSignedPreKey(device);
// Build and POST the key bundle per WA protocol spec
```

### 3. Process incoming enc nodes

In the WebSocket message handler, when you receive an `<enc>` stanza:

```csharp
// encType: "pkmsg" | "msg" | "skmsg"
// senderJid: e.g. "15551234567@s.whatsapp.net"
// groupJid: e.g. "15551234567-1617000000@g.us" (for skmsg; pass null for direct)
var decrypted = decryptionService.DecryptEncNode(
    senderJid, deviceId, encType, ciphertextBytes, groupJid);

if (decrypted != null)
    Console.WriteLine(decrypted.ToString());
```

### 4. Handle SenderKeyDistribution (group messages)

If the enc node contains a `senderKeyDistributionMessage` field (protobuf field 2),
call `RegisterSenderKeyDistribution` before trying to decrypt the skmsg:

```csharp
decryptionService.RegisterSenderKeyDistribution(groupJid, senderJid, deviceId, skdBytes);
var decrypted = decryptionService.DecryptEncNode(senderJid, deviceId, "skmsg", ciphertextBytes, groupJid);
```

## Known Limitations / Future Work

| Item | Notes |
|------|-------|
| **`InMemorySenderKeyStore`** | Group session keys are lost on restart. Persist to disk for production. |
| **Proto class generation** | `WaMessageParser` is a hand-rolled minimal reader. Generate proper C# classes from `WAWebProtobufsE2E.proto` with `protoc` for full field coverage. |
| **XEdDSA signature** | `DeviceStore` uses Ed25519 for the signed pre-key signature. WhatsApp uses XEdDSA (a Curve25519-based variant). Substitute `libsignal.XEdDSA` when available, or implement per [Signal XEdDSA spec](https://signal.org/docs/specifications/xeddsa/). |
| **Noise handshake** | `DeviceStore.NoiseKey` is generated but not yet wired into a Noise_XX handshake for the initial WA WebSocket upgrade. |

## Key Implementation Gotchas

### NSec Curve25519 Clamping

NSec's `Key.Export(RawPrivateKey)` returns **unclamped** seeds.
libsignal-protocol-dotnet has its own clamping logic **commented out**, so seeds must be
pre-clamped before `Curve.decodePrivatePoint()`:

```csharp
seed[0]  &= 248;  // clear low 3 bits
seed[31] &= 127;  // clear high bit
seed[31] |= 64;   // set second-highest bit (RFC 7748 §5)
```

`DeviceStore.ClampCurve25519Seed()` implements this.

### libsignal DJB Public Key Prefix

NSec exports 32-byte raw public keys.
libsignal's `Curve.decodePoint()` requires a **33-byte** buffer where `buf[0] == 0x05`
(the Curve25519 DJB_TYPE byte). `SignalProtocolStoreImpl.PrependDjbType()` adds this prefix.

### Sequential Pre-key IDs

Use **sequential** IDs (1, 2, 3, …) not random IDs. WhatsApp requests a specific key ID
during session establishment; a random pool risks returning the wrong key.

### Java-style API Naming

`libsignal-protocol-dotnet` is a direct Java port. All serialisation methods are lowercase:
`.serialize()`, not `.Serialize()`. Getters are `getPublicKey()`, `getPrivateKey()`, etc.

using libsignal;
using libsignal.ecc;
using libsignal.state;
using libsignal.state.impl;
using libsignal.util;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// File-backed implementation of SignalProtocolStore that persists
/// sessions, pre-keys, signed pre-keys, and identity keys under
/// ~/.whatsapp-monitor/signal-sessions/
///
/// IMPORTANT: All Curve25519 private-key seeds fed into libsignal MUST be
/// pre-clamped via DeviceStore.ClampCurve25519Seed() because
/// libsignal-protocol-dotnet has its own clamping logic commented out.
/// </summary>
public sealed class SignalProtocolStoreImpl
    : IdentityKeyStore, PreKeyStore, SignedPreKeyStore, SessionStore, SignalProtocolStore
{
    private readonly string _baseDir;

    private string SessionsDir      => Path.Combine(_baseDir, "sessions");
    private string PreKeysDir       => Path.Combine(_baseDir, "prekeys");
    private string SignedPreKeysDir => Path.Combine(_baseDir, "signed-prekeys");
    private string TrustedDir       => Path.Combine(_baseDir, "trusted");
    private string IdentityFile     => Path.Combine(_baseDir, "identity.key");

    private static string DefaultBaseDir() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".whatsapp-monitor", "signal-sessions");

    private readonly uint _localRegistrationId;
    private IdentityKeyPair _identityKeyPair;

    private readonly Dictionary<SignalProtocolAddress, SessionRecord> _sessionCache = new();
    private readonly Dictionary<uint, PreKeyRecord>        _preKeyCache = new();
    private readonly Dictionary<uint, SignedPreKeyRecord>  _signedPreKeyCache = new();

    /// <param name="device">Device key material.</param>
    /// <param name="baseDir">Override base directory (default: ~/.whatsapp-monitor/signal-sessions). Used in tests.</param>
    public SignalProtocolStoreImpl(DeviceStore device, string? baseDir = null)
    {
        _baseDir = baseDir ?? DefaultBaseDir();
        _localRegistrationId = device.RegistrationId;
        EnsureDirectories();
        _identityKeyPair = LoadOrInitIdentityKeyPair(device);
    }

    private void EnsureDirectories()
    {
        Directory.CreateDirectory(SessionsDir);
        Directory.CreateDirectory(PreKeysDir);
        Directory.CreateDirectory(SignedPreKeysDir);
        Directory.CreateDirectory(TrustedDir);
    }

    // IdentityKeyStore
    public IdentityKeyPair GetIdentityKeyPair() => _identityKeyPair;
    public uint GetLocalRegistrationId() => _localRegistrationId;

    public bool SaveIdentity(SignalProtocolAddress address, IdentityKey identityKey)
    {
        var path     = TrustedIdentityPath(address);
        var newBytes = identityKey.serialize();  // Java-style lowercase
        if (File.Exists(path))
        {
            byte[] existing = File.ReadAllBytes(path);
            if (existing.SequenceEqual(newBytes)) return false;
        }
        File.WriteAllBytes(path, newBytes);
        return true;
    }

    public bool IsTrustedIdentity(SignalProtocolAddress address, IdentityKey identityKey, Direction direction)
    {
        var path = TrustedIdentityPath(address);
        if (!File.Exists(path)) return true; // TOFU
        byte[] stored = File.ReadAllBytes(path);
        return identityKey.serialize().SequenceEqual(stored);
    }

    private string TrustedIdentityPath(SignalProtocolAddress address) =>
        Path.Combine(TrustedDir, $"{SanitizeAddress(address)}.identity");

    // PreKeyStore
    public PreKeyRecord LoadPreKey(uint preKeyId)
    {
        if (_preKeyCache.TryGetValue(preKeyId, out var cached)) return cached;
        var path = PreKeyPath(preKeyId);
        if (!File.Exists(path)) throw new InvalidKeyIdException($"Pre-key {preKeyId} not found");
        var record = new PreKeyRecord(File.ReadAllBytes(path));
        _preKeyCache[preKeyId] = record;
        return record;
    }

    public void StorePreKey(uint preKeyId, PreKeyRecord record)
    {
        File.WriteAllBytes(PreKeyPath(preKeyId), record.serialize());  // lowercase
        _preKeyCache[preKeyId] = record;
    }

    public bool ContainsPreKey(uint preKeyId) => File.Exists(PreKeyPath(preKeyId));

    public void RemovePreKey(uint preKeyId)
    {
        var path = PreKeyPath(preKeyId);
        if (File.Exists(path)) File.Delete(path);
        _preKeyCache.Remove(preKeyId);
    }

    private string PreKeyPath(uint id)      => Path.Combine(PreKeysDir, $"{id}.prekey");

    // SignedPreKeyStore
    public SignedPreKeyRecord LoadSignedPreKey(uint signedPreKeyId)
    {
        if (_signedPreKeyCache.TryGetValue(signedPreKeyId, out var cached)) return cached;
        var path = SignedPreKeyPath(signedPreKeyId);
        if (!File.Exists(path)) throw new InvalidKeyIdException($"Signed pre-key {signedPreKeyId} not found");
        var record = new SignedPreKeyRecord(File.ReadAllBytes(path));
        _signedPreKeyCache[signedPreKeyId] = record;
        return record;
    }

    public List<SignedPreKeyRecord> LoadSignedPreKeys()
    {
        var records = new List<SignedPreKeyRecord>();
        foreach (var file in Directory.GetFiles(SignedPreKeysDir, "*.sprekey"))
        {
            try { records.Add(new SignedPreKeyRecord(File.ReadAllBytes(file))); }
            catch { /* skip corrupted */ }
        }
        return records;
    }

    public void StoreSignedPreKey(uint signedPreKeyId, SignedPreKeyRecord record)
    {
        File.WriteAllBytes(SignedPreKeyPath(signedPreKeyId), record.serialize());  // lowercase
        _signedPreKeyCache[signedPreKeyId] = record;
    }

    public bool ContainsSignedPreKey(uint signedPreKeyId) => File.Exists(SignedPreKeyPath(signedPreKeyId));

    public void RemoveSignedPreKey(uint signedPreKeyId)
    {
        var path = SignedPreKeyPath(signedPreKeyId);
        if (File.Exists(path)) File.Delete(path);
        _signedPreKeyCache.Remove(signedPreKeyId);
    }

    private string SignedPreKeyPath(uint id) => Path.Combine(SignedPreKeysDir, $"{id}.sprekey");

    // SessionStore
    public SessionRecord LoadSession(SignalProtocolAddress address)
    {
        if (_sessionCache.TryGetValue(address, out var cached)) return cached;
        var path = SessionPath(address);
        SessionRecord record = File.Exists(path)
            ? new SessionRecord(File.ReadAllBytes(path))
            : new SessionRecord();
        _sessionCache[address] = record;
        return record;
    }

    public List<uint> GetSubDeviceSessions(string name)
    {
        var prefix = $"{name}_";
        var ids = new List<uint>();
        foreach (var file in Directory.GetFiles(SessionsDir, "*.session"))
        {
            var fname = Path.GetFileNameWithoutExtension(file);
            if (fname.StartsWith(prefix, StringComparison.Ordinal) &&
                uint.TryParse(fname[prefix.Length..], out var deviceId))
                ids.Add(deviceId);
        }
        return ids;
    }

    public void StoreSession(SignalProtocolAddress address, SessionRecord record)
    {
        File.WriteAllBytes(SessionPath(address), record.serialize());  // lowercase
        _sessionCache[address] = record;
    }

    public bool ContainsSession(SignalProtocolAddress address) => File.Exists(SessionPath(address));

    public void DeleteSession(SignalProtocolAddress address)
    {
        var path = SessionPath(address);
        if (File.Exists(path)) File.Delete(path);
        _sessionCache.Remove(address);
    }

    public void DeleteAllSessions(string name)
    {
        foreach (var deviceId in GetSubDeviceSessions(name))
            DeleteSession(new SignalProtocolAddress(name, deviceId));
    }

    private string SessionPath(SignalProtocolAddress address) =>
        Path.Combine(SessionsDir, $"{SanitizeAddress(address)}.session");

    // Identity key bootstrap
    private IdentityKeyPair LoadOrInitIdentityKeyPair(DeviceStore device)
    {
        if (File.Exists(IdentityFile))
        {
            var bytes = File.ReadAllBytes(IdentityFile);
            return new IdentityKeyPair(bytes);
        }

        // Seeds are pre-clamped in DeviceStore.
        // NSec exports raw 32-byte public keys; libsignal's Curve.decodePoint() expects
        // a 33-byte buffer where byte[0] == 0x05 (DJB_TYPE prefix).
        var privPoint = Curve.decodePrivatePoint(device.IdentityPrivate);
        var pubBytes  = PrependDjbType(device.IdentityPublic);
        var pubKey    = Curve.decodePoint(pubBytes, 0);
        var pair      = new IdentityKeyPair(new IdentityKey(pubKey), privPoint);
        File.WriteAllBytes(IdentityFile, pair.serialize());  // lowercase
        return pair;
    }

    /// <summary>
    /// libsignal's Curve.decodePoint() requires the first byte to be 0x05 (Curve25519 DJB_TYPE).
    /// NSec exports raw 32-byte public keys without this prefix — add it here.
    /// </summary>
    private static byte[] PrependDjbType(byte[] rawPub32)
    {
        var buf = new byte[33];
        buf[0] = 0x05;  // DJB_TYPE
        Buffer.BlockCopy(rawPub32, 0, buf, 1, 32);
        return buf;
    }

    private static string SanitizeAddress(SignalProtocolAddress address) =>
        $"{address.Name.Replace('/', '_').Replace(':', '-')}_{address.DeviceId}";
}

using Microsoft.Extensions.Logging;
using libsignal;
using libsignal.ecc;
using libsignal.state;
using libsignal.util;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// Manages the pool of one-time pre-keys used for Signal session establishment.
///
/// Pre-keys are sequential (not random) to prevent pool-mismatch when WhatsApp
/// requests a specific key ID. The next-ID counter is persisted at
/// ~/.whatsapp-monitor/session-data/next-prekey-id.txt
/// </summary>
public sealed class PreKeyManager
{
    private readonly string _baseDir;

    private string NextIdFile => Path.Combine(_baseDir, "session-data", "next-prekey-id.txt");
    private string PreKeysPoolDir => Path.Combine(_baseDir, "signal-sessions", "prekeys");

    private static string DefaultBaseDir() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".whatsapp-monitor");

    public const int RefillThreshold = 20;
    public const int BatchSize = 100;

    private readonly SignalProtocolStoreImpl _store;
    private readonly Microsoft.Extensions.Logging.ILogger<PreKeyManager> _logger;

    public PreKeyManager(
        SignalProtocolStoreImpl store,
        Microsoft.Extensions.Logging.ILogger<PreKeyManager>? logger = null,
        string? baseDir = null)
    {
        _store   = store;
        _logger  = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<PreKeyManager>.Instance;
        _baseDir = baseDir ?? DefaultBaseDir();
    }

    public int CountAvailable()
    {
        if (!Directory.Exists(PreKeysPoolDir)) return 0;
        return Directory.GetFiles(PreKeysPoolDir, "*.prekey").Length;
    }

    public void EnsurePoolFilled()
    {
        if (CountAvailable() >= RefillThreshold) return;
        GenerateBatch(BatchSize);
    }

    public List<PreKeyRecord> GenerateBatch(int count)
    {
        uint nextId = ReadNextId();
        Directory.CreateDirectory(Path.GetDirectoryName(NextIdFile)!);

        // KeyHelper.generatePreKeys returns IList<PreKeyRecord>
        var records = KeyHelper.generatePreKeys(nextId, (uint)count).ToList();
        foreach (var r in records)
            _store.StorePreKey(r.getId(), r);

        uint newNextId = nextId + (uint)count;
        File.WriteAllText(NextIdFile, newNextId.ToString());
        _logger.LogInformation("Generated {Count} pre-keys (IDs {Start}-{End})", count, nextId, newNextId - 1);
        return records;
    }

    /// <summary>
    /// Generates a fresh signed pre-key and stores it.
    /// Uses KeyHelper.generateSignedPreKey which handles signing internally.
    /// </summary>
    public SignedPreKeyRecord GenerateSignedPreKey(DeviceStore device)
    {
        var idPair = _store.GetIdentityKeyPair();
        var record = KeyHelper.generateSignedPreKey(idPair, device.SignedPreKeyId);
        _store.StoreSignedPreKey(device.SignedPreKeyId, record);
        _logger.LogInformation("Generated signed pre-key ID={Id}", device.SignedPreKeyId);
        return record;
    }

    private uint ReadNextId()
    {
        if (File.Exists(NextIdFile) &&
            uint.TryParse(File.ReadAllText(NextIdFile).Trim(), out var id))
            return id;
        return 1;
    }
}


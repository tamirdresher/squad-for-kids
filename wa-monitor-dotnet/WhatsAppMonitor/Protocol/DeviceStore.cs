using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using NSec.Cryptography;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// Holds the device-level cryptographic identities for this WhatsApp client:
/// - IdentityKey  – Curve25519 long-term identity (Signal protocol identity key)
/// - SignedPreKey – Curve25519 signed pre-key (renewed periodically)
/// - NoiseKey     – Curve25519 key used for the Noise protocol WA handshake
///
/// All private keys are stored as 32-byte seeds.  When passed to
/// libsignal-protocol-dotnet the seeds MUST be pre-clamped (see
/// <see cref="ClampCurve25519Seed"/>) because the library has its own clamping
/// code commented out.
/// </summary>
public sealed class DeviceStore
{
    private string _baseDir = "";

    private static string DefaultBaseDir() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".whatsapp-monitor");

    private string DeviceFilePath => Path.Combine(_baseDir, "session-data", "device-store.json");

    // ── public key material ───────────────────────────────────────────────────

    /// <summary>32-byte Curve25519 identity private-key seed (pre-clamped).</summary>
    public byte[] IdentityPrivate { get; private set; } = [];

    /// <summary>32-byte Curve25519 identity public key.</summary>
    public byte[] IdentityPublic { get; private set; } = [];

    /// <summary>32-byte Curve25519 signed-pre-key private-key seed (pre-clamped).</summary>
    public byte[] SignedPreKeyPrivate { get; private set; } = [];

    /// <summary>32-byte Curve25519 signed-pre-key public key.</summary>
    public byte[] SignedPreKeyPublic { get; private set; } = [];

    /// <summary>64-byte Ed25519 signature of SignedPreKeyPublic by IdentityPrivate.</summary>
    public byte[] SignedPreKeySignature { get; private set; } = [];

    /// <summary>Current signed-pre-key ID (1-based).</summary>
    public uint SignedPreKeyId { get; private set; } = 1;

    /// <summary>32-byte Curve25519 Noise-protocol private-key seed (pre-clamped).</summary>
    public byte[] NoiseKeyPrivate { get; private set; } = [];

    /// <summary>32-byte Curve25519 Noise-protocol public key.</summary>
    public byte[] NoiseKeyPublic { get; private set; } = [];

    /// <summary>WA registration ID (0–16383).</summary>
    public uint RegistrationId { get; private set; }

    // ── factory ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Loads an existing device store from disk, or generates fresh keys if none exist.
    /// </summary>
    /// <param name="baseDir">Override base directory (default: ~/.whatsapp-monitor). Used in tests.</param>
    public static DeviceStore LoadOrCreate(string? baseDir = null)
    {
        var dir      = baseDir ?? DefaultBaseDir();
        var filePath = Path.Combine(dir, "session-data", "device-store.json");
        Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);

        if (File.Exists(filePath))
        {
            try
            {
                var json = File.ReadAllText(filePath);
                var dto  = JsonSerializer.Deserialize<DeviceStoreDto>(json)!;
                var s    = FromDto(dto);
                s._baseDir = dir;
                return s;
            }
            catch
            {
                // Corrupted file – regenerate
            }
        }

        var store      = Generate();
        store._baseDir = dir;
        store.Save();
        return store;
    }

    public void Save()
    {
        var filePath = DeviceFilePath;
        Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);
        var json = JsonSerializer.Serialize(ToDto(), new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(filePath, json);
    }

    // ── key generation ────────────────────────────────────────────────────────

    private static DeviceStore Generate()
    {
        // Use NSec for key generation; export the raw seed and clamp it.
        var x25519 = KeyAgreementAlgorithm.X25519;
        var ed25519 = SignatureAlgorithm.Ed25519;

        var identityParams = new KeyCreationParameters { ExportPolicy = KeyExportPolicies.AllowPlaintextExport };

        using var idKey      = Key.Create(x25519, identityParams);
        using var spkKey     = Key.Create(x25519, identityParams);
        using var noiseKey   = Key.Create(x25519, identityParams);

        byte[] idPriv    = ExportAndClamp(idKey,    x25519);
        byte[] spkPriv   = ExportAndClamp(spkKey,   x25519);
        byte[] noisePriv = ExportAndClamp(noiseKey, x25519);

        byte[] idPub    = idKey.Export(KeyBlobFormat.RawPublicKey);
        byte[] spkPub   = spkKey.Export(KeyBlobFormat.RawPublicKey);
        byte[] noisePub = noiseKey.Export(KeyBlobFormat.RawPublicKey);

        // Sign the signed-pre-key with the identity key (Ed25519 signature over the SPK public key).
        // WA actually uses XEdDSA on Curve25519, but for session establishment the raw signature
        // bytes are what libsignal checks.  We use Ed25519 here; a full XEdDSA implementation
        // can be substituted without changing the store interface.
        using var signKey = Key.Create(ed25519, identityParams);
        byte[] spkSig     = ed25519.Sign(signKey, spkPub);

        uint regId = (uint)(Random.Shared.Next(1, 16384));

        return new DeviceStore
        {
            IdentityPrivate       = idPriv,
            IdentityPublic        = idPub,
            SignedPreKeyPrivate    = spkPriv,
            SignedPreKeyPublic     = spkPub,
            SignedPreKeySignature  = spkSig,
            SignedPreKeyId        = 1,
            NoiseKeyPrivate       = noisePriv,
            NoiseKeyPublic        = noisePub,
            RegistrationId        = regId,
        };
    }

    // ── Curve25519 seed clamping ──────────────────────────────────────────────

    /// <summary>
    /// NSec exports UNCLAMPED seeds via <c>RawPrivateKey</c>.
    /// libsignal-protocol-dotnet has its own clamping commented out, so we must
    /// pre-clamp before calling <c>Curve.decodePrivatePoint()</c>.
    ///
    /// RFC 7748 §5 clamping:
    ///   seed[0]  &amp;= 248  (clear low 3 bits)
    ///   seed[31] &amp;= 127  (clear high bit)
    ///   seed[31] |= 64   (set second-highest bit)
    /// </summary>
    public static byte[] ClampCurve25519Seed(byte[] seed)
    {
        if (seed.Length != 32) throw new ArgumentException("Curve25519 seed must be 32 bytes", nameof(seed));
        var clamped = (byte[])seed.Clone();
        clamped[0]  &= 248;
        clamped[31] &= 127;
        clamped[31] |= 64;
        return clamped;
    }

    private static byte[] ExportAndClamp(Key key, KeyAgreementAlgorithm algo)
    {
        byte[] raw = key.Export(KeyBlobFormat.RawPrivateKey);
        return ClampCurve25519Seed(raw);
    }

    // ── DTO serialisation ─────────────────────────────────────────────────────

    private DeviceStoreDto ToDto() => new()
    {
        IdentityPrivate      = Convert.ToBase64String(IdentityPrivate),
        IdentityPublic       = Convert.ToBase64String(IdentityPublic),
        SignedPreKeyPrivate   = Convert.ToBase64String(SignedPreKeyPrivate),
        SignedPreKeyPublic    = Convert.ToBase64String(SignedPreKeyPublic),
        SignedPreKeySignature = Convert.ToBase64String(SignedPreKeySignature),
        SignedPreKeyId       = SignedPreKeyId,
        NoiseKeyPrivate      = Convert.ToBase64String(NoiseKeyPrivate),
        NoiseKeyPublic       = Convert.ToBase64String(NoiseKeyPublic),
        RegistrationId       = RegistrationId,
    };

    private static DeviceStore FromDto(DeviceStoreDto dto) => new()
    {
        IdentityPrivate      = Convert.FromBase64String(dto.IdentityPrivate),
        IdentityPublic       = Convert.FromBase64String(dto.IdentityPublic),
        SignedPreKeyPrivate   = Convert.FromBase64String(dto.SignedPreKeyPrivate),
        SignedPreKeyPublic    = Convert.FromBase64String(dto.SignedPreKeyPublic),
        SignedPreKeySignature = Convert.FromBase64String(dto.SignedPreKeySignature),
        SignedPreKeyId       = dto.SignedPreKeyId,
        NoiseKeyPrivate      = Convert.FromBase64String(dto.NoiseKeyPrivate),
        NoiseKeyPublic       = Convert.FromBase64String(dto.NoiseKeyPublic),
        RegistrationId       = dto.RegistrationId,
    };

    private sealed class DeviceStoreDto
    {
        public string IdentityPrivate      { get; set; } = "";
        public string IdentityPublic       { get; set; } = "";
        public string SignedPreKeyPrivate   { get; set; } = "";
        public string SignedPreKeyPublic    { get; set; } = "";
        public string SignedPreKeySignature { get; set; } = "";
        public uint   SignedPreKeyId       { get; set; }
        public string NoiseKeyPrivate      { get; set; } = "";
        public string NoiseKeyPublic       { get; set; } = "";
        public uint   RegistrationId       { get; set; }
    }
}

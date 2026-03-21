using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor;

/// <summary>
/// Exports and imports the Chromium persistent-context directory used by
/// <see cref="WhatsAppWebMonitor"/> so a WhatsApp Web session can be transferred
/// across machines without re-scanning a QR code.
///
/// <para><b>Security model:</b> The profile contains localStorage acting as a
/// session token. When encryption is enabled the archive uses AES-256-GCM with
/// a 12-byte random nonce; the key is supplied externally and never stored with
/// the blob.</para>
///
/// <para><b>Wire format (encrypted):</b>
/// <c>magic(4) + nonce(12) + tag(16) + ciphertext(n)</c> — Base64-encoded.</para>
///
/// <para><b>WhatsApp constraint:</b> Only one active connection per device is
/// allowed. Stop all instances before importing on a new machine.</para>
/// </summary>
public sealed class SessionManager
{
    private static readonly byte[] _magic = Encoding.ASCII.GetBytes("WAGC");

    private readonly string _profileDir;
    private readonly ILogger<SessionManager> _logger;

    private static readonly string[] ExcludeDirs =
        ["Cache", "Code Cache", "GPUCache", "ShaderCache", "blob_storage"];

    private static readonly string[] ExcludeFileExact =
        ["Lock", "SingletonLock", "SingletonCookie", "SingletonSocket"];

    private static readonly string[] ExcludeFilePrefixes = ["CrashpadMetrics"];

    /// <param name="profileDir">
    ///   Chromium user-data dir — same value as <see cref="WhatsAppMonitorOptions.UserDataDir"/>.
    /// </param>
    public SessionManager(string profileDir, ILogger<SessionManager>? logger = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(profileDir);
        _profileDir = profileDir;
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions
                              .NullLogger<SessionManager>.Instance;
    }

    // ── Export ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// Packs the Chromium profile into a zip, optionally encrypts with AES-256-GCM,
    /// and returns a Base64-encoded blob safe for storage as a secret.
    /// </summary>
    /// <param name="encryptionKey">32-byte key, or <see langword="null"/> for plain blob.</param>
    public async Task<string> ExportAsync(byte[]? encryptionKey = null)
    {
        if (!Directory.Exists(_profileDir))
            throw new DirectoryNotFoundException(
                $"Profile not found: {_profileDir}. " +
                "Run the monitor once and complete QR authentication first.");

        _logger.LogInformation("Exporting session from {Dir}", _profileDir);
        var zipBytes = await CreateProfileZipAsync();
        _logger.LogInformation("Zipped: {KB:F1} KB", zipBytes.Length / 1024.0);

        byte[] payload = encryptionKey is not null ? Encrypt(zipBytes, encryptionKey) : zipBytes;
        var blob = Convert.ToBase64String(payload);
        _logger.LogInformation("Export complete — {Chars} chars", blob.Length);
        return blob;
    }

    // ── Import ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// Restores a blob from <see cref="ExportAsync"/> to the local profile directory.
    /// </summary>
    /// <param name="blob">Base64-encoded blob (value of <c>WA_MONITOR_SESSION</c>).</param>
    /// <param name="encryptionKey">32-byte key for encrypted blobs; <see langword="null"/> for plain.</param>
    public async Task ImportAsync(string blob, byte[]? encryptionKey = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(blob);

        byte[] rawBytes;
        try { rawBytes = Convert.FromBase64String(blob.Trim()); }
        catch (FormatException ex)
        { throw new ArgumentException("Not valid Base64.", nameof(blob), ex); }

        byte[] zipBytes = IsEncryptedBlob(rawBytes)
            ? Decrypt(rawBytes, encryptionKey
                ?? throw new InvalidOperationException(
                    "Blob is encrypted (WAGC header) but no key was provided. Set WA_SESSION_KEY."))
            : rawBytes;

        _logger.LogInformation("Importing session to {Dir}", _profileDir);
        if (Directory.Exists(_profileDir))
        {
            _logger.LogWarning("Removing existing profile at {Dir}", _profileDir);
            Directory.Delete(_profileDir, recursive: true);
        }
        Directory.CreateDirectory(_profileDir);

        var tmpZip = Path.GetTempFileName() + ".zip";
        try
        {
            await File.WriteAllBytesAsync(tmpZip, zipBytes);
            ZipFile.ExtractToDirectory(tmpZip, _profileDir, overwriteFiles: true);
            _logger.LogInformation("Session imported successfully.");
        }
        finally { if (File.Exists(tmpZip)) File.Delete(tmpZip); }
    }

    // ── Resolve key from environment ───────────────────────────────────────────

    /// <summary>
    /// Reads <c>WA_SESSION_KEY</c> from the environment (Base64 32-byte value).
    /// Returns <see langword="null"/> when not set.
    /// </summary>
    public static byte[]? GetKeyFromEnvironment()
    {
        var raw = Environment.GetEnvironmentVariable("WA_SESSION_KEY");
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var key = Convert.FromBase64String(raw);
        if (key.Length != 32)
            throw new InvalidOperationException(
                $"WA_SESSION_KEY must be 32 bytes (44-char Base64). Got {key.Length}.");
        return key;
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private async Task<byte[]> CreateProfileZipAsync()
    {
        var tmpDir = Path.Combine(Path.GetTempPath(), "wa-profile-" + Guid.NewGuid().ToString("N"));
        var tmpZip = Path.GetTempFileName() + ".zip";
        try
        {
            CopyDirectory(_profileDir, tmpDir);
            await Task.Run(() => ZipFile.CreateFromDirectory(tmpDir, tmpZip));
            return await File.ReadAllBytesAsync(tmpZip);
        }
        finally
        {
            if (Directory.Exists(tmpDir)) Directory.Delete(tmpDir, recursive: true);
            if (File.Exists(tmpZip))      File.Delete(tmpZip);
        }
    }

    private static void CopyDirectory(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (var file in Directory.EnumerateFiles(src))
        {
            var name = Path.GetFileName(file);
            if (IsExcludedFile(name)) continue;
            File.Copy(file, Path.Combine(dst, name), overwrite: true);
        }
        foreach (var dir in Directory.EnumerateDirectories(src))
        {
            var name = Path.GetFileName(dir);
            if (ExcludeDirs.Contains(name, StringComparer.OrdinalIgnoreCase)) continue;
            CopyDirectory(dir, Path.Combine(dst, name));
        }
    }

    private static bool IsExcludedFile(string n) =>
        ExcludeFileExact.Contains(n, StringComparer.OrdinalIgnoreCase) ||
        ExcludeFilePrefixes.Any(p => n.StartsWith(p, StringComparison.OrdinalIgnoreCase)) ||
        n.EndsWith(".log", StringComparison.OrdinalIgnoreCase) ||
        n.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase);

    // ── AES-256-GCM ────────────────────────────────────────────────────────────

    private static byte[] Encrypt(byte[] plaintext, byte[] key)
    {
        if (key.Length != 32) throw new ArgumentException("Key must be 32 bytes.", nameof(key));
        var nonce = new byte[12]; var tag = new byte[16]; var cipher = new byte[plaintext.Length];
        RandomNumberGenerator.Fill(nonce);
        using var aes = new AesGcm(key, tagSizeInBytes: 16);
        aes.Encrypt(nonce, plaintext, cipher, tag);
        var payload = new byte[4 + 12 + 16 + cipher.Length];
        Buffer.BlockCopy(_magic,  0, payload,  0,  4);
        Buffer.BlockCopy(nonce,   0, payload,  4, 12);
        Buffer.BlockCopy(tag,     0, payload, 16, 16);
        Buffer.BlockCopy(cipher,  0, payload, 32, cipher.Length);
        return payload;
    }

    private static byte[] Decrypt(byte[] payload, byte[] key)
    {
        if (key.Length != 32) throw new ArgumentException("Key must be 32 bytes.", nameof(key));
        if (payload.Length < 33) throw new CryptographicException("Blob too short.");
        var plaintext = new byte[payload.Length - 32];
        using var aes = new AesGcm(key, tagSizeInBytes: 16);
        aes.Decrypt(payload[4..16], payload[32..], payload[16..32], plaintext);
        return plaintext;
    }

    private static bool IsEncryptedBlob(byte[] b) =>
        b.Length > 32 &&
        b[0] == _magic[0] && b[1] == _magic[1] && b[2] == _magic[2] && b[3] == _magic[3];
}

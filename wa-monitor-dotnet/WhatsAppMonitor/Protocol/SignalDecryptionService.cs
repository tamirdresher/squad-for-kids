using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// High-level service that wires together <see cref="SignalProtocolStoreImpl"/>,
/// <see cref="MessageDecryptor"/>, and <see cref="WaMessageParser"/> to provide
/// one-call decryption of incoming WhatsApp message frames.
///
/// Typical usage:
/// <code>
/// var device  = DeviceStore.LoadOrCreate();
/// var service = new SignalDecryptionService(device, logger);
/// service.EnsurePreKeyPool();
///
/// // When an enc node arrives from the WhatsApp WebSocket:
/// var result = service.DecryptEncNode(
///     senderJid:      "15551234567@s.whatsapp.net",
///     senderDeviceId: 0,
///     encType:        "pkmsg",   // or "msg" / "skmsg"
///     ciphertext:     encNodeBodyBytes);
///
/// Console.WriteLine(result);  // e.g. "[text] Hello!"
/// </code>
/// </summary>
public sealed class SignalDecryptionService
{
    private readonly DeviceStore _device;
    private readonly SignalProtocolStoreImpl _store;
    private readonly PreKeyManager _preKeyManager;
    private readonly MessageDecryptor _decryptor;
    private readonly WaMessageParser _parser;
    private readonly ILogger<SignalDecryptionService> _logger;

    public SignalDecryptionService(
        DeviceStore device,
        ILogger<SignalDecryptionService>? logger = null)
    {
        _device        = device;
        _logger        = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<SignalDecryptionService>.Instance;
        _store         = new SignalProtocolStoreImpl(device);
        _preKeyManager = new PreKeyManager(_store, null);
        _decryptor     = new MessageDecryptor(_store, null);
        _parser        = new WaMessageParser(null);
    }

    // ── pre-key pool ──────────────────────────────────────────────────────────

    /// <summary>
    /// Ensures the one-time pre-key pool is filled and the signed pre-key is
    /// available.  Call once at startup before handling any messages.
    /// </summary>
    public void EnsurePreKeyPool()
    {
        _preKeyManager.EnsurePoolFilled();

        if (!_store.ContainsSignedPreKey(_device.SignedPreKeyId))
            _preKeyManager.GenerateSignedPreKey(_device);

        _logger.LogInformation(
            "Pre-key pool ready (available={Count}, signedPreKeyId={SpkId})",
            _preKeyManager.CountAvailable(), _device.SignedPreKeyId);
    }

    // ── decryption entry point ────────────────────────────────────────────────

    /// <summary>
    /// Decrypts and parses an incoming <c>enc</c> node payload.
    /// </summary>
    /// <param name="senderJid">Sender JID, e.g. <c>15551234567@s.whatsapp.net</c></param>
    /// <param name="senderDeviceId">Sender device ID (0 for primary).</param>
    /// <param name="encType">Value of the <c>type</c> attribute: <c>pkmsg</c>, <c>msg</c>, or <c>skmsg</c>.</param>
    /// <param name="ciphertext">Ciphertext bytes from the <c>enc</c> node body.</param>
    /// <returns>
    /// Parsed <see cref="WaDecryptedMessage"/> or <c>null</c> if decryption fails.
    /// When <see cref="WaDecryptedMessage.MessageType"/> is
    /// <see cref="WaMessageType.SenderKeyDistribution"/>, also call
    /// <see cref="ProcessSenderKeyDistribution"/> before the next group message
    /// from the same sender.
    /// </returns>
    public WaDecryptedMessage? DecryptEncNode(
        string senderJid,
        uint   senderDeviceId,
        string encType,
        byte[] ciphertext)
    {
        byte[]? plaintext = _decryptor.Decrypt(senderJid, senderDeviceId, encType, ciphertext);
        if (plaintext is null) return null;

        var msg = _parser.Parse(plaintext);
        if (msg is null) return null;

        // Automatically register sender-key distribution messages for group chat
        if (msg.MessageType == WaMessageType.SenderKeyDistribution &&
            msg.SenderKeyDistribution is not null)
        {
            // For group SenderKeyDistribution, senderJid is the sender, groupId would
            // come from the outer message stanza. Here we use senderJid as fallback.
            _decryptor.ProcessSenderKeyDistribution(senderJid, senderJid, senderDeviceId, msg.SenderKeyDistribution);
            _logger.LogInformation("Auto-registered SenderKey for group sender {Jid}", senderJid);
        }

        _logger.LogInformation(
            "Decrypted {Type} from {Jid}: {Summary}",
            encType, senderJid, msg);

        return msg;
    }

    /// <summary>
    /// Explicitly registers a sender-key distribution message.
    /// </summary>
    public void ProcessSenderKeyDistribution(string groupId, string senderJid, uint deviceId, byte[] distributionBytes) =>
        _decryptor.ProcessSenderKeyDistribution(groupId, senderJid, deviceId, distributionBytes);

    // ── store accessors (for pairing/registration flows) ─────────────────────

    /// <summary>The underlying Signal protocol store (identity keys, sessions, pre-keys).</summary>
    public SignalProtocolStoreImpl Store => _store;

    /// <summary>The device store (long-term identity, signed pre-key, noise key).</summary>
    public DeviceStore Device => _device;
}

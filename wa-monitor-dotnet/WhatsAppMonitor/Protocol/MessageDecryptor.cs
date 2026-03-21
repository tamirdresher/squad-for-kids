using libsignal;
using libsignal.groups;
using libsignal.groups.state;
using libsignal.protocol;
using libsignal.state;
using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// Decrypts incoming WhatsApp end-to-end encrypted message payloads.
///
/// WA uses the Signal protocol. The enc node type attribute determines which
/// message type to expect:
///   pkmsg  - PreKeySignalMessage (first message, establishes session)
///   msg    - SignalMessage (subsequent messages in established session)
///   skmsg  - SenderKeyMessage (group messages)
///
/// After decryption the plaintext is a WAWebProtobufsE2E.Message protobuf.
/// Parse it with WaMessageParser.
/// </summary>
public sealed class MessageDecryptor
{
    private readonly SignalProtocolStoreImpl _store;
    private readonly ILogger<MessageDecryptor> _logger;
    private readonly GroupSessionBuilder _groupSessionBuilder;
    private readonly InMemorySenderKeyStore _senderKeyStore;

    public MessageDecryptor(
        SignalProtocolStoreImpl store,
        ILogger<MessageDecryptor>? logger = null)
    {
        _store               = store;
        _logger              = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<MessageDecryptor>.Instance;
        _senderKeyStore      = new InMemorySenderKeyStore();
        _groupSessionBuilder = new GroupSessionBuilder(_senderKeyStore);
    }

    /// <summary>Decrypts an incoming enc payload.</summary>
    /// <param name="senderJid">e.g. "15551234567@s.whatsapp.net"</param>
    /// <param name="senderDeviceId">Device ID (0 for primary)</param>
    /// <param name="encType">pkmsg | msg | skmsg</param>
    /// <param name="ciphertext">Ciphertext bytes from enc node body</param>
    /// <returns>Decrypted plaintext protobuf bytes, or null on failure</returns>
    public byte[]? Decrypt(string senderJid, uint senderDeviceId, string encType, byte[] ciphertext)
    {
        try
        {
            return encType switch
            {
                "pkmsg" => DecryptPreKeyMessage(senderJid, senderDeviceId, ciphertext),
                "msg"   => DecryptSignalMessage(senderJid,  senderDeviceId, ciphertext),
                "skmsg" => DecryptSenderKeyMessage(senderJid, ciphertext),
                _       => throw new NotSupportedException($"Unknown enc type: {encType}")
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to decrypt {EncType} from {Jid}:{Device}", encType, senderJid, senderDeviceId);
            return null;
        }
    }

    /// <summary>
    /// Processes a SenderKeyDistributionMessage for group chats.
    /// groupId is the group JID (e.g. "1234567890-1234@g.us").
    /// MUST be called before decrypting any skmsg from this sender in this group.
    /// </summary>
    public void ProcessSenderKeyDistribution(
        string groupId,
        string senderJid,
        uint   senderDeviceId,
        byte[] distributionBytes)
    {
        var senderAddress = new SignalProtocolAddress(senderJid, senderDeviceId);
        var senderKeyName = new SenderKeyName(groupId, senderAddress);
        var msg           = new SenderKeyDistributionMessage(distributionBytes);
        _groupSessionBuilder.process(senderKeyName, msg);
        _logger.LogDebug("Processed SenderKeyDistribution from {Jid}:{Dev} in group {Group}",
            senderJid, senderDeviceId, groupId);
    }

    // pkmsg
    private byte[] DecryptPreKeyMessage(string jid, uint deviceId, byte[] ciphertext)
    {
        var address = new SignalProtocolAddress(jid, deviceId);
        var cipher  = new SessionCipher(_store, address);
        var msg     = new PreKeySignalMessage(ciphertext);
        _logger.LogDebug("Decrypting pkmsg from {Jid}:{Device} (preKeyId={PreKeyId})",
            jid, deviceId, msg.getPreKeyId());
        byte[] plaintext = cipher.decrypt(msg);
        _logger.LogInformation("Session established with {Jid}:{Device}", jid, deviceId);
        return Unpad(plaintext);
    }

    // msg
    private byte[] DecryptSignalMessage(string jid, uint deviceId, byte[] ciphertext)
    {
        var address = new SignalProtocolAddress(jid, deviceId);
        var cipher  = new SessionCipher(_store, address);
        var msg     = new SignalMessage(ciphertext);
        _logger.LogDebug("Decrypting msg from {Jid}:{Device}", jid, deviceId);
        return Unpad(cipher.decrypt(msg));
    }

    // skmsg — groupId must be passed via the enc node''s participant/from attributes
    private byte[] DecryptSenderKeyMessage(string senderJid, byte[] ciphertext)
    {
        // For simplicity, use senderJid as both group and sender here.
        // In production, pass the actual group JID from the message stanza.
        var senderAddress = new SignalProtocolAddress(senderJid, 0);
        var senderKeyName = new SenderKeyName(senderJid, senderAddress);
        var cipher        = new GroupCipher(_senderKeyStore, senderKeyName);
        _logger.LogDebug("Decrypting skmsg from {Jid}", senderJid);
        return Unpad(cipher.decrypt(ciphertext));
    }

    /// <summary>Removes WA PKCS#7 padding appended before Signal encryption.</summary>
    private static byte[] Unpad(byte[] data)
    {
        if (data.Length == 0) return data;
        int padLen = data[^1];
        if (padLen < 1 || padLen > 16 || padLen > data.Length) return data;
        for (int i = data.Length - padLen; i < data.Length; i++)
            if (data[i] != padLen) return data;
        return data[..^padLen];
    }
}

/// <summary>
/// In-memory SenderKeyStore for group sessions.
/// SenderKeyName is in libsignal.groups namespace.
/// SenderKeyRecord is in libsignal.groups namespace.
/// </summary>
internal sealed class InMemorySenderKeyStore : SenderKeyStore
{
    private readonly Dictionary<string, SenderKeyRecord> _store = new();

    public void storeSenderKey(SenderKeyName senderKeyName, SenderKeyRecord record) =>
        _store[Key(senderKeyName)] = record;

    public SenderKeyRecord loadSenderKey(SenderKeyName senderKeyName) =>
        _store.TryGetValue(Key(senderKeyName), out var r) ? r : new SenderKeyRecord();

    private static string Key(SenderKeyName n) =>
        $"{n.getGroupId()}::{n.getSender().Name}::{n.getSender().DeviceId}";
}


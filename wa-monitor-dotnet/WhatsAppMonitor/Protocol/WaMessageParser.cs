using Google.Protobuf;
using Microsoft.Extensions.Logging;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// Parses the plaintext bytes produced by <see cref="MessageDecryptor"/> into
/// human-readable message content.
///
/// After Signal decryption, the payload is a serialised
/// <c>WAWebProtobufsE2E.Message</c> protobuf.  The most common fields are:
///
/// <list type="bullet">
///   <item><term>conversation</term> — plain text message</item>
///   <item><term>extendedTextMessage</term> — text with link preview</item>
///   <item><term>imageMessage</term> — image with optional caption</item>
///   <item><term>videoMessage</term> — video with optional caption</item>
///   <item><term>audioMessage</term> — voice/audio note</item>
///   <item><term>documentMessage</term> — file attachment</item>
///   <item><term>stickerMessage</term> — sticker</item>
///   <item><term>reactionMessage</term> — emoji reaction to a message</item>
///   <item><term>senderKeyDistributionMessage</term> — group sender-key distribution</item>
/// </list>
///
/// Protobuf field numbers are taken from the public whatsmeow proto schema
/// (go.mau.fi/whatsmeow/proto/waE2E).
/// </summary>
public sealed class WaMessageParser
{
    private readonly ILogger<WaMessageParser> _logger;

    public WaMessageParser(ILogger<WaMessageParser>? logger = null)
    {
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<WaMessageParser>.Instance;
    }

    // ── public API ────────────────────────────────────────────────────────────

    /// <summary>
    /// Parses a decrypted <c>WAWebProtobufsE2E.Message</c> protobuf.
    /// </summary>
    public WaDecryptedMessage? Parse(byte[] plaintext)
    {
        if (plaintext.Length == 0) return null;

        try
        {
            // Parse with a hand-rolled minimal protobuf reader to avoid
            // depending on generated proto classes at this stage.
            // Once .proto files are integrated this should be replaced with
            // the generated WaE2E.Message class.
            return ParseMinimal(plaintext);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to parse WAWebProtobufsE2E.Message ({Len} bytes)", plaintext.Length);
            return null;
        }
    }

    // ── minimal proto reader ──────────────────────────────────────────────────

    /// <summary>
    /// Minimal hand-rolled reader for the fields we care about.
    /// Field numbers from the WAWebProtobufsE2E.Message schema:
    ///   1  = conversation (string)
    ///   2  = senderKeyDistributionMessage (embedded message)
    ///   3  = imageMessage       (embedded)
    ///   4  = contactMessage     (embedded)
    ///   5  = locationMessage    (embedded)
    ///   6  = extendedTextMessage (embedded, field 1 = text)
    ///   7  = documentMessage    (embedded)
    ///   8  = audioMessage       (embedded)
    ///   9  = videoMessage       (embedded)
    ///  17  = reactionMessage    (embedded, field 1 = key, field 2 = text)
    ///  25  = stickerMessage     (embedded)
    /// </summary>
    private static WaDecryptedMessage ParseMinimal(byte[] data)
    {
        var reader = new CodedInputStream(data);
        var result = new WaDecryptedMessage { RawBytes = data };

        while (!reader.IsAtEnd)
        {
            uint tag    = reader.ReadTag();
            int  field  = (int)(tag >> 3);
            int  wtype  = (int)(tag & 0x7);

            switch (field)
            {
                case 1 when wtype == 2: // conversation (string)
                    result.Conversation = reader.ReadString();
                    result.MessageType  = WaMessageType.Text;
                    break;

                case 6 when wtype == 2: // extendedTextMessage
                {
                    var bytes = reader.ReadBytes();
                    result.Conversation = ParseExtendedTextMessage(bytes.ToByteArray());
                    result.MessageType  = WaMessageType.Text;
                    break;
                }

                case 2 when wtype == 2: // senderKeyDistributionMessage
                    result.MessageType       = WaMessageType.SenderKeyDistribution;
                    result.SenderKeyDistribution = reader.ReadBytes().ToByteArray();
                    break;

                case 17 when wtype == 2: // reactionMessage
                {
                    var bytes = reader.ReadBytes();
                    result.MessageType  = WaMessageType.Reaction;
                    result.Conversation = ParseReactionText(bytes.ToByteArray());
                    break;
                }

                case 3  when wtype == 2: // imageMessage
                    result.MessageType = WaMessageType.Image;
                    result.MediaCaption = ParseMediaCaption(reader.ReadBytes().ToByteArray(), captionField: 7);
                    break;

                case 7 when wtype == 2: // documentMessage
                    result.MessageType  = WaMessageType.Document;
                    result.MediaCaption = ParseMediaCaption(reader.ReadBytes().ToByteArray(), captionField: 8);
                    break;

                case 8 when wtype == 2: // audioMessage
                    result.MessageType = WaMessageType.Audio;
                    reader.SkipLastField();
                    break;

                case 9 when wtype == 2: // videoMessage
                    result.MessageType  = WaMessageType.Video;
                    result.MediaCaption = ParseMediaCaption(reader.ReadBytes().ToByteArray(), captionField: 7);
                    break;

                case 25 when wtype == 2: // stickerMessage
                    result.MessageType = WaMessageType.Sticker;
                    reader.SkipLastField();
                    break;

                default:
                    reader.SkipLastField();
                    break;
            }
        }

        return result;
    }

    private static string? ParseExtendedTextMessage(byte[] data)
    {
        // extendedTextMessage field 1 = text (string)
        return ReadStringField(data, fieldNumber: 1);
    }

    private static string? ParseReactionText(byte[] data)
    {
        // reactionMessage field 2 = text (string) — the emoji
        return ReadStringField(data, fieldNumber: 2);
    }

    private static string? ParseMediaCaption(byte[] data, int captionField)
    {
        return ReadStringField(data, captionField);
    }

    private static string? ReadStringField(byte[] data, int fieldNumber)
    {
        try
        {
            var reader = new CodedInputStream(data);
            while (!reader.IsAtEnd)
            {
                uint tag   = reader.ReadTag();
                int  field = (int)(tag >> 3);
                int  wtype = (int)(tag & 0x7);
                if (field == fieldNumber && wtype == 2)
                    return reader.ReadString();
                reader.SkipLastField();
            }
        }
        catch { /* ignore */ }
        return null;
    }
}

// ── Result types ──────────────────────────────────────────────────────────────

public enum WaMessageType
{
    Unknown,
    Text,
    Image,
    Video,
    Audio,
    Document,
    Sticker,
    Reaction,
    SenderKeyDistribution,
}

public sealed class WaDecryptedMessage
{
    /// <summary>Original (still-encrypted or raw) protobuf bytes.</summary>
    public byte[] RawBytes { get; init; } = [];

    /// <summary>Detected message type.</summary>
    public WaMessageType MessageType { get; set; } = WaMessageType.Unknown;

    /// <summary>Text content (conversation text, caption, or reaction emoji).</summary>
    public string? Conversation { get; set; }

    /// <summary>Caption for media messages (image/video/document).</summary>
    public string? MediaCaption { get; set; }

    /// <summary>Raw bytes of a SenderKeyDistributionMessage (for group chat setup).</summary>
    public byte[]? SenderKeyDistribution { get; set; }

    public override string ToString() =>
        MessageType switch
        {
            WaMessageType.Text     => $"[text] {Conversation}",
            WaMessageType.Image    => $"[image] {MediaCaption ?? "(no caption)"}",
            WaMessageType.Video    => $"[video] {MediaCaption ?? "(no caption)"}",
            WaMessageType.Audio    => "[audio]",
            WaMessageType.Document => $"[document] {MediaCaption ?? "(no title)"}",
            WaMessageType.Sticker  => "[sticker]",
            WaMessageType.Reaction => $"[reaction] {Conversation}",
            WaMessageType.SenderKeyDistribution => "[sender-key-distribution]",
            _                      => $"[{MessageType}]",
        };
}

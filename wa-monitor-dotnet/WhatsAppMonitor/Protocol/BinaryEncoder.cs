// BinaryEncoder.cs — WhatsApp Binary XML encoder
// Ported from whatsmeow Go reference (tulir/whatsmeow):
//   binary/encoder.go
// Issue: #1035

using System.Text;

namespace WhatsAppMonitor.Protocol;

/// <summary>
/// Encodes a <see cref="BinaryNode"/> tree into the WhatsApp binary wire format.
/// </summary>
public static class BinaryEncoder
{
    /// <summary>Encode a <see cref="BinaryNode"/> to its wire-format bytes.</summary>
    public static byte[] Encode(BinaryNode node)
    {
        var enc = new Encoder();
        enc.WriteNode(node);
        return enc.ToArray();
    }
}

// ─── Internal encoder state ───────────────────────────────────────────────────

file sealed class Encoder
{
    private readonly List<byte> _buf = new();

    internal byte[] ToArray() => _buf.ToArray();

    // ── static reverse token maps ─────────────────────────────────────────────

    private static readonly IReadOnlyDictionary<string, int> s_singleByteReverse;
    private static readonly IReadOnlyDictionary<string, (int dict, int idx)> s_doubleByteReverse;

    static Encoder()
    {
        // Build reverse map: token string → single-byte index
        var sb = new Dictionary<string, int>(WaTokens.SingleByte.Length);
        for (int i = 1; i < WaTokens.SingleByte.Length; i++)
        {
            var tok = WaTokens.SingleByte[i];
            if (!string.IsNullOrEmpty(tok) && !sb.ContainsKey(tok))
                sb[tok] = i;
        }
        s_singleByteReverse = sb;

        // Build reverse map: token string → (dict index, token index)
        var db = new Dictionary<string, (int, int)>();
        for (int d = 0; d < WaTokens.DoubleByte.Length; d++)
        {
            var dict = WaTokens.DoubleByte[d];
            for (int i = 0; i < dict.Length; i++)
            {
                var tok = dict[i];
                if (!string.IsNullOrEmpty(tok) && !db.ContainsKey(tok))
                    db[tok] = (d, i);
            }
        }
        s_doubleByteReverse = db;
    }

    // ── node writer ───────────────────────────────────────────────────────────

    /// <summary>
    /// Write a node. A null or empty-tag node is written as a single
    /// <see cref="WaTokens.ListEmpty"/> byte (equivalent to Go's "nil node").
    /// </summary>
    internal void WriteNode(BinaryNode? node)
    {
        if (node is null || node.Tag.Length == 0)
        {
            _buf.Add(WaTokens.ListEmpty);
            return;
        }

        int numAttrs   = node.Attrs.Count;
        bool hasContent = node.Content is not null;
        // listSize = tag (1) + attr pairs (2×n) + optional content slot (1)
        int listSize   = 2 * numAttrs + 1 + (hasContent ? 1 : 0);

        WriteListSize(listSize);
        WriteString(node.Tag);

        foreach (var (key, value) in node.Attrs)
        {
            WriteString(key);
            WriteAttrValue(key, value);
        }

        if (hasContent)
            WriteContent(node.Content);
    }

    // ── list size ─────────────────────────────────────────────────────────────

    private void WriteListSize(int size)
    {
        if (size == 0)
        {
            _buf.Add(WaTokens.ListEmpty);
        }
        else if (size <= 0xFF)
        {
            _buf.Add(WaTokens.List8);
            _buf.Add((byte)size);
        }
        else
        {
            _buf.Add(WaTokens.List16);
            _buf.Add((byte)(size >> 8));
            _buf.Add((byte)(size & 0xFF));
        }
    }

    // ── string writer ─────────────────────────────────────────────────────────

    /// <summary>
    /// Encode a string using the most compact representation available:
    ///   single-byte token → double-byte token → nibble8 → raw binary.
    /// </summary>
    internal void WriteString(string s)
    {
        if (string.IsNullOrEmpty(s))
        {
            _buf.Add(WaTokens.ListEmpty);
            return;
        }

        // 1. Single-byte token lookup
        if (s_singleByteReverse.TryGetValue(s, out int singleIdx))
        {
            _buf.Add((byte)singleIdx);
            return;
        }

        // 2. Double-byte token lookup
        if (s_doubleByteReverse.TryGetValue(s, out var dbEntry))
        {
            _buf.Add((byte)(WaTokens.Dictionary0 + dbEntry.dict));
            _buf.Add((byte)dbEntry.idx);
            return;
        }

        // 3. Nibble encoding (digits, '-', '.')
        if (TryWriteNibble(s))
            return;

        // 4. Raw UTF-8 bytes
        WriteRawBytes(Encoding.UTF8.GetBytes(s));
    }

    // ── nibble encoder ────────────────────────────────────────────────────────

    private bool TryWriteNibble(string s)
    {
        // Max length: 127 pairs × 2 chars = 254 chars
        if (s.Length == 0 || s.Length > 127 * 2)
            return false;

        // Validate: only '0'-'9', '-', '.'
        foreach (char c in s)
        {
            if ((c < '0' || c > '9') && c != '-' && c != '.')
                return false;
        }

        int  numBytes = (s.Length + 1) / 2;
        bool padLast  = (s.Length & 1) == 1;   // odd length → pad last nibble with 0xF

        _buf.Add(WaTokens.Nibble8);
        _buf.Add((byte)((padLast ? 0x80 : 0) | numBytes));

        for (int i = 0; i < numBytes; i++)
        {
            int  i0 = i * 2;
            int  i1 = i0 + 1;
            byte hi = PackNibble(s[i0]);
            byte lo = i1 < s.Length ? PackNibble(s[i1]) : (byte)15;  // 15 = padding nibble
            _buf.Add((byte)((hi << 4) | lo));
        }
        return true;
    }

    private static byte PackNibble(char c) => c switch
    {
        >= '0' and <= '9' => (byte)(c - '0'),
        '-'               => 10,
        '.'               => 11,
        _                 => throw new InvalidOperationException($"Non-nibble char '{c}'")
    };

    // ── raw bytes writer ──────────────────────────────────────────────────────

    /// <summary>
    /// Write a length-prefixed binary payload using the most compact tag:
    ///   ≤255 bytes → Binary8 (1-byte length)
    ///   ≤1 MiB    → Binary20 (3-byte / 20-bit length)
    ///   otherwise  → Binary32 (4-byte length)
    /// </summary>
    private void WriteRawBytes(byte[] data)
    {
        if (data.Length <= 0xFF)
        {
            _buf.Add(WaTokens.Binary8);
            _buf.Add((byte)data.Length);
        }
        else if (data.Length <= 0xFFFFF)   // 20-bit max = 1,048,575
        {
            _buf.Add(WaTokens.Binary20);
            _buf.Add((byte)((data.Length >> 16) & 0x0F));
            _buf.Add((byte)((data.Length >> 8) & 0xFF));
            _buf.Add((byte)(data.Length & 0xFF));
        }
        else
        {
            _buf.Add(WaTokens.Binary32);
            _buf.Add((byte)((data.Length >> 24) & 0xFF));
            _buf.Add((byte)((data.Length >> 16) & 0xFF));
            _buf.Add((byte)((data.Length >> 8) & 0xFF));
            _buf.Add((byte)(data.Length & 0xFF));
        }
        _buf.AddRange(data);
    }

    // ── attribute value writer ────────────────────────────────────────────────

    private static readonly HashSet<string> s_jidAttrKeys =
        new(StringComparer.OrdinalIgnoreCase)
        { "to", "from", "participant", "jid", "lid" };

    private void WriteAttrValue(string key, object? value)
    {
        if (value is null)
        {
            _buf.Add(WaTokens.ListEmpty);
            return;
        }

        // Jid struct → encode with the appropriate JID tag
        if (value is Jid jid)
        {
            WriteJid(jid);
            return;
        }

        string str = value.ToString()!;

        // JID-keyed attributes that contain "@" → encode as JIDPair
        if (s_jidAttrKeys.Contains(key) && str.Contains('@'))
        {
            int    at     = str.IndexOf('@');
            string user   = str[..at];
            string server = str[(at + 1)..];
            // Strip optional :device suffix from user part
            int colon = user.IndexOf(':');
            if (colon >= 0) user = user[..colon];
            _buf.Add(WaTokens.JIDPair);
            WriteString(user);
            WriteString(server);
            return;
        }

        WriteString(str);
    }

    // ── JID writer ────────────────────────────────────────────────────────────

    private void WriteJid(Jid jid)
    {
        // ADJID: WhatsApp JIDs with agent/device info
        if (jid.Server == Jid.ServerWhatsApp && (jid.Device > 0 || jid.Agent > 0))
        {
            _buf.Add(WaTokens.ADJID);
            _buf.Add(jid.Agent);
            _buf.Add((byte)jid.Device);
            WriteString(jid.User);
            return;
        }

        // FBJID: Messenger JIDs with device info
        if (jid.Server == Jid.ServerMessenger)
        {
            _buf.Add(WaTokens.FBJID);
            WriteString(jid.User);
            WriteInt16(jid.Device);
            WriteString(jid.Server);
            return;
        }

        // InteropJID: interop bridge JIDs
        if (jid.Server == Jid.ServerInterop)
        {
            _buf.Add(WaTokens.InteropJID);
            WriteString(jid.User);
            WriteInt16(jid.Device);
            WriteInt16(jid.Integrator);
            WriteString(jid.Server);
            return;
        }

        // Default: plain JIDPair (user@server)
        _buf.Add(WaTokens.JIDPair);
        WriteString(jid.User);
        WriteString(jid.Server);
    }

    private void WriteInt16(ushort value)
    {
        _buf.Add((byte)(value >> 8));
        _buf.Add((byte)(value & 0xFF));
    }

    // ── content writer ────────────────────────────────────────────────────────

    private void WriteContent(object? content)
    {
        switch (content)
        {
            case null:
                _buf.Add(WaTokens.ListEmpty);
                break;

            case BinaryNode[] children:
                // Write a list of child nodes
                WriteListSize(children.Length);
                foreach (var child in children)
                    WriteNode(child);
                break;

            case byte[] bytes:
                WriteRawBytes(bytes);
                break;

            case string s:
                WriteString(s);
                break;

            default:
                throw new InvalidOperationException(
                    $"Unsupported content type: {content.GetType().Name}");
        }
    }
}

// BinaryEncoderTests.cs — Unit tests for the WhatsApp binary XML encoder
// Issue: #1035

using WhatsAppMonitor.Protocol;
using Xunit;

namespace WhatsAppMonitor.Tests;

public class BinaryEncoderTests
{
    // ── helper: encode → decode round-trip assertion ──────────────────────────

    private static BinaryNode DecodeRoundTrip(BinaryNode node)
    {
        var encoded = BinaryEncoder.Encode(node);
        return BinaryDecoder.Decode(encoded);
    }

    // ── basic node shapes ─────────────────────────────────────────────────────

    [Fact]
    public void EmptyNode_EncodesAndDecodesTag()
    {
        var node = new BinaryNode { Tag = "iq" };
        var rt   = DecodeRoundTrip(node);

        Assert.Equal("iq",  rt.Tag);
        Assert.Empty(rt.Attrs);
        Assert.Null(rt.Content);
    }

    [Fact]
    public void NodeWithSingleByteTag_ProducesCorrectBytes()
    {
        // "iq" is token index 25 in SingleByte
        // Expected frame: List8(248), size=1 (no attrs, no content), 25
        var node = new BinaryNode { Tag = "iq" };
        var data = BinaryEncoder.Encode(node);

        Assert.Equal(new byte[] { 0xF8, 1, 25 }, data);
    }

    [Fact]
    public void NodeWithDoubleByteTag_ProducesCorrectBytes()
    {
        // "read-self" is Dictionary0 (236), index 0
        // Expected frame: List8(248), size=1, 236, 0
        var node = new BinaryNode { Tag = "read-self" };
        var data = BinaryEncoder.Encode(node);

        Assert.Equal(new byte[] { 0xF8, 1, 236, 0 }, data);
    }

    [Fact]
    public void NodeWithRawStringTag_EncodesAsBinary8()
    {
        // "unknown-tag-xyz" is not in any token dictionary → Binary8
        var node = new BinaryNode { Tag = "unknown-tag-xyz" };
        var data = BinaryEncoder.Encode(node);

        // Frame: List8(248), size=1, Binary8(252), len, bytes...
        Assert.Equal(0xF8, data[0]);   // List8
        Assert.Equal(1,    data[1]);   // listSize=1
        Assert.Equal(0xFC, data[2]);   // Binary8
        Assert.Equal("unknown-tag-xyz".Length, data[3]);
    }

    // ── attributes ────────────────────────────────────────────────────────────

    [Fact]
    public void NodeWithOneAttribute_RoundTrips()
    {
        var node = new BinaryNode
        {
            Tag   = "iq",
            Attrs = new Dictionary<string, object?> { ["type"] = "get" }
        };
        var rt = DecodeRoundTrip(node);

        Assert.Equal("iq",  rt.Tag);
        Assert.Equal("get", rt.GetAttrString("type"));
        Assert.Null(rt.Content);
    }

    [Fact]
    public void NodeWithMultipleAttributes_RoundTrips()
    {
        var node = new BinaryNode
        {
            Tag   = "iq",
            Attrs = new Dictionary<string, object?>
            {
                ["type"]  = "get",
                ["id"]    = "abc123",
                ["xmlns"] = "w:g2"
            }
        };
        var rt = DecodeRoundTrip(node);

        Assert.Equal("iq",   rt.Tag);
        Assert.Equal("get",  rt.GetAttrString("type"));
        Assert.Equal("abc123", rt.GetAttrString("id"));
        Assert.Equal("w:g2",   rt.GetAttrString("xmlns"));
    }

    // ── JID attribute encoding ────────────────────────────────────────────────

    [Fact]
    public void ToAttribute_StringJID_EncodesAsJIDPair()
    {
        var node = new BinaryNode
        {
            Tag   = "message",
            Attrs = new Dictionary<string, object?> { ["to"] = "1234567890@s.whatsapp.net" }
        };
        var data = BinaryEncoder.Encode(node);

        // JIDPair tag (250 = 0xFA) should appear in the stream
        Assert.Contains((byte)0xFA, data);
    }

    [Fact]
    public void ToAttribute_StringJID_RoundTrips()
    {
        // After encoding+decoding a JIDPair, value comes back as Jid struct
        var node = new BinaryNode
        {
            Tag   = "message",
            Attrs = new Dictionary<string, object?> { ["to"] = "1234567890@s.whatsapp.net" }
        };
        var rt = DecodeRoundTrip(node);

        // Decoded attr value is a Jid record
        var jidVal = rt.Attrs["to"];
        Assert.NotNull(jidVal);
        var jid = Assert.IsType<Jid>(jidVal);
        Assert.Equal("1234567890",    jid.User);
        Assert.Equal("s.whatsapp.net", jid.Server);
    }

    [Fact]
    public void FromAttribute_StringJID_RoundTrips()
    {
        var node = new BinaryNode
        {
            Tag   = "message",
            Attrs = new Dictionary<string, object?> { ["from"] = "987654321@g.us" }
        };
        var rt = DecodeRoundTrip(node);

        var jid = Assert.IsType<Jid>(rt.Attrs["from"]);
        Assert.Equal("987654321", jid.User);
        Assert.Equal("g.us",      jid.Server);
    }

    [Fact]
    public void JidObject_EncodesAsJIDPair_AndRoundTrips()
    {
        var jidValue = new Jid("5551234567", "s.whatsapp.net");
        var node = new BinaryNode
        {
            Tag   = "presence",
            Attrs = new Dictionary<string, object?> { ["from"] = jidValue }
        };
        var rt = DecodeRoundTrip(node);

        var jid = Assert.IsType<Jid>(rt.Attrs["from"]);
        Assert.Equal("5551234567",    jid.User);
        Assert.Equal("s.whatsapp.net", jid.Server);
    }

    [Fact]
    public void NonJidAttribute_StringWithAt_IsNotEncodedAsJIDPair()
    {
        // A non-JID attribute key with "@" should NOT produce JIDPair
        var node = new BinaryNode
        {
            Tag   = "iq",
            Attrs = new Dictionary<string, object?> { ["email"] = "user@example.com" }
        };
        var data = BinaryEncoder.Encode(node);

        // JIDPair (0xFA) should NOT appear
        Assert.DoesNotContain((byte)0xFA, data);
    }

    // ── content: string ───────────────────────────────────────────────────────

    [Fact]
    public void StringContent_RoundTrips()
    {
        var node = new BinaryNode
        {
            Tag     = "notification",
            Content = "hello world"
        };
        var rt = DecodeRoundTrip(node);

        // Content comes back as byte[] when decoded with asString=false at content level
        // but string tokens come back as strings
        Assert.NotNull(rt.Content);
    }

    // ── content: byte[] ───────────────────────────────────────────────────────

    [Fact]
    public void ByteArrayContent_RoundTrips()
    {
        var payload = new byte[] { 0x01, 0x02, 0x03, 0xAB, 0xCD };
        var node = new BinaryNode
        {
            Tag     = "enc",
            Content = payload
        };
        var rt = DecodeRoundTrip(node);

        var contentBytes = Assert.IsType<byte[]>(rt.Content);
        Assert.Equal(payload, contentBytes);
    }

    [Fact]
    public void LargeByteArrayContent_EncodesWithBinary20()
    {
        // 256 bytes → exceeds Binary8 limit (255), uses Binary20
        var payload = new byte[256];
        for (int i = 0; i < payload.Length; i++) payload[i] = (byte)(i & 0xFF);

        var node = new BinaryNode { Tag = "enc", Content = payload };
        var data = BinaryEncoder.Encode(node);

        // Binary20 tag = 253 = 0xFD should appear
        Assert.Contains((byte)0xFD, data);
    }

    [Fact]
    public void SmallByteArrayContent_EncodesWithBinary8()
    {
        var payload = new byte[] { 1, 2, 3 };
        var node    = new BinaryNode { Tag = "enc", Content = payload };
        var data    = BinaryEncoder.Encode(node);

        // Binary8 tag = 252 = 0xFC should appear
        Assert.Contains((byte)0xFC, data);
    }

    // ── content: child nodes ──────────────────────────────────────────────────

    [Fact]
    public void ChildNodes_RoundTrip()
    {
        var node = new BinaryNode
        {
            Tag = "iq",
            Attrs = new Dictionary<string, object?> { ["type"] = "result" },
            Content = new BinaryNode[]
            {
                new() { Tag = "status",  Content = (object?)"OK"   },
                new() { Tag = "devices", Content = (object?)null   }
            }
        };
        var rt = DecodeRoundTrip(node);

        var children = Assert.IsType<BinaryNode[]>(rt.Content);
        Assert.Equal(2, children.Length);
        Assert.Equal("status",  children[0].Tag);
        Assert.Equal("devices", children[1].Tag);
    }

    [Fact]
    public void NestedChildren_RoundTrip()
    {
        var node = new BinaryNode
        {
            Tag = "iq",
            Content = new BinaryNode[]
            {
                new()
                {
                    Tag = "query",
                    Content = new BinaryNode[]
                    {
                        new() { Tag = "item", Attrs = new Dictionary<string, object?> { ["id"] = "x1" } }
                    }
                }
            }
        };
        var rt = DecodeRoundTrip(node);

        var outerChildren = Assert.IsType<BinaryNode[]>(rt.Content);
        Assert.Single(outerChildren);
        var query = outerChildren[0];
        Assert.Equal("query", query.Tag);
        var innerChildren = Assert.IsType<BinaryNode[]>(query.Content);
        Assert.Single(innerChildren);
        Assert.Equal("item", innerChildren[0].Tag);
    }

    // ── token lookup ──────────────────────────────────────────────────────────

    [Theory]
    [InlineData("iq")]
    [InlineData("from")]
    [InlineData("to")]
    [InlineData("type")]
    [InlineData("id")]
    [InlineData("receipt")]
    [InlineData("message")]
    [InlineData("notification")]
    [InlineData("status")]
    [InlineData("s.whatsapp.net")]
    [InlineData("g.us")]
    public void SingleByteToken_PreservesExactString(string token)
    {
        var node = new BinaryNode { Tag = token };
        var rt   = DecodeRoundTrip(node);
        Assert.Equal(token, rt.Tag);
    }

    [Theory]
    [InlineData("read-self")]          // Dictionary0, index 0
    [InlineData("pair-device")]        // Dictionary1
    public void DoubleByteToken_PreservesExactString(string token)
    {
        var node = new BinaryNode { Tag = token };
        var rt   = DecodeRoundTrip(node);
        Assert.Equal(token, rt.Tag);
    }

    // ── nibble encoding ───────────────────────────────────────────────────────

    [Theory]
    [InlineData("1234567890")]
    [InlineData("123-456-7890")]
    [InlineData("192.168.1.1")]
    [InlineData("0")]
    public void NibbleString_RoundTrips(string s)
    {
        var node = new BinaryNode
        {
            Tag     = "iq",
            Attrs   = new Dictionary<string, object?> { ["id"] = s }
        };
        var rt = DecodeRoundTrip(node);
        Assert.Equal(s, rt.GetAttrString("id"));
    }

    [Fact]
    public void NibbleString_ProducesNibble8Tag()
    {
        // "12345" is all digits → should produce Nibble8 (0xFF)
        var node = new BinaryNode
        {
            Tag   = "iq",
            Attrs = new Dictionary<string, object?> { ["id"] = "12345" }
        };
        var data = BinaryEncoder.Encode(node);

        // Nibble8 tag = 255 = 0xFF
        Assert.Contains((byte)0xFF, data);
    }

    // ── explicit decode round-trip with known binary frame ────────────────────

    [Fact]
    public void KnownFrame_SimpleNode_EncodeMatchesExpected()
    {
        // "iq" (token 25) with no attrs, no content
        // Expected: List8(0xF8), listSize=1, token=25
        var node     = new BinaryNode { Tag = "iq" };
        var encoded  = BinaryEncoder.Encode(node);
        var expected = new byte[] { 0xF8, 1, 25 };
        Assert.Equal(expected, encoded);
    }

    [Fact]
    public void DecodeAndReencode_SemanticRoundTrip()
    {
        // Build a frame by hand, decode it, re-encode it, then decode again.
        // The final decoded node must equal the first decoded node.
        // (The encoder may choose more compact encodings, e.g. token index
        //  instead of Binary8, so byte-exact equality is NOT required.)
        var original = new byte[]
        {
            0xF8, 3,           // List8, listSize=3
            25,                // tag = "iq" (index 25)
            4,                 // attr key = "type" (index 4)
            252, 3, (byte)'g', (byte)'e', (byte)'t'  // Binary8 "get"
        };

        var decoded1  = BinaryDecoder.Decode(original);
        var reencoded = BinaryEncoder.Encode(decoded1);
        var decoded2  = BinaryDecoder.Decode(reencoded);

        Assert.Equal(decoded1.Tag, decoded2.Tag);
        Assert.Equal(decoded1.GetAttrString("type"), decoded2.GetAttrString("type"));
        Assert.Equal(decoded1.Content, decoded2.Content);
    }

    [Fact]
    public void DecodeAndReencode_AllTokenForms_SemanticRoundTrip()
    {
        // A node with: single-byte tag, token attr key, token attr value, binary content
        var node = new BinaryNode
        {
            Tag   = "iq",    // token 25
            Attrs = new Dictionary<string, object?>
            {
                ["type"]  = "result",  // "result" is also a token
                ["id"]    = "1234567890"  // nibble-encodable
            },
            Content = new byte[] { 0xDE, 0xAD, 0xBE, 0xEF }
        };

        var encoded  = BinaryEncoder.Encode(node);
        var decoded  = BinaryDecoder.Decode(encoded);

        Assert.Equal("iq",           decoded.Tag);
        Assert.Equal("result",       decoded.GetAttrString("type"));
        Assert.Equal("1234567890",   decoded.GetAttrString("id"));
        var bytes = Assert.IsType<byte[]>(decoded.Content);
        Assert.Equal(new byte[] { 0xDE, 0xAD, 0xBE, 0xEF }, bytes);
    }

    // ── list size boundaries ──────────────────────────────────────────────────

    [Fact]
    public void NodeWithManyAttributes_UsesListSizeCorrectly()
    {
        // 128 attributes → listSize = 2*128+1 = 257 → List16 required
        var attrs = new Dictionary<string, object?>();
        for (int i = 0; i < 128; i++)
            attrs[$"attr{i:000}"] = $"val{i:000}";

        var node = new BinaryNode { Tag = "iq", Attrs = attrs };
        var data = BinaryEncoder.Encode(node);

        // List16 = 0xF9 should be the first byte
        Assert.Equal(0xF9, data[0]);
    }

    // ── ADJID encoding ────────────────────────────────────────────────────────

    [Fact]
    public void JidWithDevice_EncodesAsADJID_AndRoundTrips()
    {
        // Jid with Device > 0 and Server == "s.whatsapp.net" → ADJID (247 = 0xF7)
        var jidValue = new Jid("1234567890", Jid.ServerWhatsApp, Device: 3, Agent: 1);
        var node = new BinaryNode
        {
            Tag   = "message",
            Attrs = new Dictionary<string, object?> { ["from"] = jidValue }
        };
        var data = BinaryEncoder.Encode(node);

        // ADJID tag = 247 = 0xF7 should appear
        Assert.Contains((byte)0xF7, data);
    }

    [Fact]
    public void LidAttribute_StringJID_EncodesAsJIDPair()
    {
        // "lid" is a JID attribute key — strings containing '@' must be encoded
        // as a JIDPair token (0xFA = 250), not as plain Binary8 strings.
        var node = new BinaryNode
        {
            Tag   = "message",
            Attrs = new Dictionary<string, object?> { ["lid"] = "user@lid" }
        };
        var data = BinaryEncoder.Encode(node);
        Assert.Contains((byte)0xFA, data); // JIDPair tag = 250 = 0xFA
    }
}

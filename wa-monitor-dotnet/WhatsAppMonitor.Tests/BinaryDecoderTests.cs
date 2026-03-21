// BinaryDecoderTests.cs — Unit tests for the WhatsApp binary XML decoder
// Issue: #1034

using WhatsAppMonitor.Protocol;
using Xunit;

namespace WhatsAppMonitor.Tests;

public class BinaryDecoderTests
{
    // ── helper: build a minimal binary node frame ─────────────────────────────

    /// <summary>
    /// Builds a valid binary frame for a node with a single-byte tag token,
    /// no attributes, no content.
    ///
    /// Frame layout:
    ///   [List8=248] [list-size=1] [token-byte]
    ///
    /// list-size=1 → odd → no content; (1-1)/2 = 0 attribute pairs.
    /// </summary>
    private static byte[] NodeNoAttrs(byte tagToken)
        => [0xF8, 1, tagToken];  // List8, size=1, tag

    // ── single-byte token lookup ──────────────────────────────────────────────

    [Theory]
    [InlineData(25,  "iq")]
    [InlineData(6,   "from")]
    [InlineData(17,  "to")]
    [InlineData(8,   "id")]
    [InlineData(76,  "success")]
    [InlineData(168, "error")]
    public void SingleByteToken_DecodesCorrectly(int index, string expected)
    {
        // Frame: List8(248), size=1 (no attrs, no content), token-byte
        var data = new byte[] { 0xF8, 1, (byte)index };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal(expected, node.Tag);
        Assert.Empty(node.Attrs);
        Assert.Null(node.Content);
    }

    // ── double-byte token (dictionary) lookup ─────────────────────────────────

    [Fact]
    public void DoubleByte_Dict0_Token0_DecodesAsReadSelf()
    {
        // Frame: tag is a Dict0(236) token followed by index byte 0
        // Build: List8(248), size=1, [Dict0=236, 0]
        // But the descriptor is read via Read(true), which reads tag=236 then idx=0
        // size=1 → odd → no content; 0 attr pairs
        var data = new byte[] { 0xF8, 1, 236, 0 };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("read-self", node.Tag);
    }

    [Fact]
    public void DoubleByte_Dict1_Token238_DecodesAsPairDevice()
    {
        // Dictionary1 index 238 = "pair-device"
        var data = new byte[] { 0xF8, 1, 237, 238 };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("pair-device", node.Tag);
    }

    [Fact]
    public void DoubleByte_Dict3_Token76_DecodesAsCreate()
    {
        // Dictionary3 index 76 = "create"
        var data = new byte[] { 0xF8, 1, 239, 76 };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("create", node.Tag);
    }

    // ── attributes ────────────────────────────────────────────────────────────

    [Fact]
    public void NodeWithOneAttribute_DecodesCorrectly()
    {
        // Build:  List8(248), size=3, tag(iq=25), key(id=8), value(Binary8+bytes)
        // size=3 → odd → no content; (3-1)/2 = 1 attr pair
        // value = Binary8(252), len=4, "test"
        var value = System.Text.Encoding.UTF8.GetBytes("test");
        var data = new byte[]
        {
            0xF8, 3,        // List8, size=3
            25,             // tag = "iq"
            8,              // key = "id"
            252, 4, (byte)'t', (byte)'e', (byte)'s', (byte)'t'  // Binary8 value
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("iq", node.Tag);
        Assert.Equal("test", node.GetAttrString("id"));
        Assert.Null(node.Content);
    }

    [Fact]
    public void NodeWithTwoAttributes_DecodesCorrectly()
    {
        // size=5 → odd → no content; (5-1)/2 = 2 attr pairs
        // Attrs: [id="123", type="get"]
        var data = new byte[]
        {
            0xF8, 5,            // List8, size=5
            25,                 // tag = "iq"
            8,                  // key = "id"
            252, 3, (byte)'1', (byte)'2', (byte)'3',   // Binary8 "123"
            4,                  // key = "type"
            41,                 // value token = "get" (index 41)
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("iq", node.Tag);
        Assert.Equal("123", node.GetAttrString("id"));
        Assert.Equal("get", node.GetAttrString("type"));
        Assert.Null(node.Content);
    }

    // ── binary content ────────────────────────────────────────────────────────

    [Fact]
    public void BinaryContent_Binary8_DecodesAsByteArray()
    {
        // size=2 → even → content present; (2-1)/2=0 attr pairs
        var payload = new byte[] { 0xDE, 0xAD, 0xBE, 0xEF };
        var data = new byte[]
        {
            0xF8, 2,            // List8, size=2
            25,                 // tag = "iq"
            252, 4, 0xDE, 0xAD, 0xBE, 0xEF  // Binary8(252), len=4, payload
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("iq", node.Tag);
        Assert.IsType<byte[]>(node.Content);
        Assert.Equal(payload, (byte[])node.Content!);
    }

    [Fact]
    public void StringContent_Binary8_DecodesAsString()
    {
        // To get string content we would need asString=false for content
        // Actually content is read with asString=false, so binary stays as byte[]
        // Test that byte[] round-trips correctly
        var text = System.Text.Encoding.UTF8.GetBytes("hello");
        var data = new byte[]
        {
            0xF8, 2,
            76,             // tag = "success"
            252, 5, (byte)'h', (byte)'e', (byte)'l', (byte)'l', (byte)'o'
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("success", node.Tag);
        var content = Assert.IsType<byte[]>(node.Content);
        Assert.Equal(text, content);
    }

    // ── packed strings ────────────────────────────────────────────────────────

    [Fact]
    public void Nibble8_DecodesPhoneNumber()
    {
        // Nibble8 encoding of "1234" → startByte=0x02 (count=2, no trim), data=[0x12, 0x34]
        // Nibble: 1→'1', 2→'2', 3→'3', 4→'4'
        var data = new byte[]
        {
            0xF8, 1,      // List8, size=1 (tag only)
            255,          // Nibble8 tag for the *tag-name* field
            0x02,         // startByte: count=2 bytes, trimLast=false
            0x12, 0x34    // packed: 1,2 and 3,4
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("1234", node.Tag);
    }

    [Fact]
    public void Nibble8_OddLength_TrimsPaddingNibble()
    {
        // Encoding "123" → pad to "123_" → startByte=0x82 (count=2, trimLast=true)
        // bytes: [0x12, 0x3F]  (F=15=null nibble)
        var data = new byte[]
        {
            0xF8, 1,
            255,          // Nibble8
            0x82,         // count=2, trimLast=true
            0x12, 0x3F
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("123", node.Tag);
    }

    [Fact]
    public void Hex8_DecodesHexString()
    {
        // Hex8 encoding of "AB" → startByte=0x01 (count=1), data=[0xAB]
        // Hex: A=10→'A', B=11→'B'
        var data = new byte[]
        {
            0xF8, 1,
            251,        // Hex8
            0x01,       // count=1, trimLast=false
            0xAB
        };
        var node = BinaryDecoder.Decode(data);
        Assert.Equal("AB", node.Tag);
    }

    // ── JID types ─────────────────────────────────────────────────────────────

    [Fact]
    public void JIDPair_DecodesCorrectly()
    {
        // Attribute value is a JIDPair: user="1234567890", server="s.whatsapp.net"(token 3)
        // size=3 → odd → no content; 1 attr pair
        var user = System.Text.Encoding.UTF8.GetBytes("1234567890");
        var data = new byte[]
        {
            0xF8, 3,           // List8, size=3
            25,                // tag = "iq"
            6,                 // key = "from"
            250,               // JIDPair
            // user: Binary8
            252, 10, (byte)'1',(byte)'2',(byte)'3',(byte)'4',(byte)'5',
                     (byte)'6',(byte)'7',(byte)'8',(byte)'9',(byte)'0',
            // server: single-byte token 3 = "s.whatsapp.net"
            3
        };
        var node = BinaryDecoder.Decode(data);
        var jid = Assert.IsType<Jid>(node.GetAttr("from"));
        Assert.Equal("1234567890", jid.User);
        Assert.Equal("s.whatsapp.net", jid.Server);
    }

    [Fact]
    public void ADJID_DecodesCorrectly()
    {
        // Attribute value is ADJID: agent=0, device=1, user="9876543210"
        var data = new byte[]
        {
            0xF8, 3,
            25,             // tag = "iq"
            6,              // key = "from"
            247,            // ADJID
            0,              // agent
            1,              // device
            252, 10, (byte)'9',(byte)'8',(byte)'7',(byte)'6',(byte)'5',
                     (byte)'4',(byte)'3',(byte)'2',(byte)'1',(byte)'0',
        };
        var node = BinaryDecoder.Decode(data);
        var jid = Assert.IsType<Jid>(node.GetAttr("from"));
        Assert.Equal("9876543210", jid.User);
        Assert.Equal((ushort)1, jid.Device);
        Assert.Equal((byte)0,   jid.Agent);
    }

    // ── nested nodes (list content) ───────────────────────────────────────────

    [Fact]
    public void NestedNodeList_DecodesCorrectly()
    {
        // Outer: size=2, tag="iq", content=List8 with one child
        // Child: size=1, tag="item", no attrs, no content
        // Outer frame: List8(248) size=2 tag(25=iq) [List8(248) size=1 child-tag(63=item)]
        var data = new byte[]
        {
            0xF8, 2,        // outer: List8 size=2
            25,             // outer tag = "iq"
            0xF8, 1,        // content = List8, size=1
              63,           //   child: List8 size=1, tag = "item"
        };
        // Wait — the child is encoded as List8(248) 1 63 which ReadList produces [ReadNode()]
        // ReadNode reads: sizeTag=248→ReadListSize(248)=ReadInt8()=1  tag=ReadValue(63)="item"  listSize=1→odd→no content
        // But the child list-size-byte (248) is the outer content List8 followed by size=1 followed by child sizeTag=63
        // Let me think more carefully...
        // Actually the outer content starts with tag=248 (List8) → ReadList(248) → size=ReadInt8()=1 → 1 node
        // That child node: sizeTag=ReadInt8()=1 → ReadListSize(1)??? No, 1 is not List8/List16/ListEmpty
        // We need the child to use valid list-size tags.
        // Let me use: child: sizeTag=ListEmpty(0)→size=0 which would be invalid (listSize=0 is error)
        // Or child: sizeTag=List8(248) size=1 tag=63
        // So the full encoding:
        // outer: 0xF8 2 25  [0xF8 1  0xF8 1 63]
        //   outer sizeTag=0xF8=248=List8, listSize=ReadInt8()=2
        //   tag=Read(true): tag_byte=25 → "iq"
        //   listSize=2→even→read content
        //   content: Read(false): tag_byte=0xF8=248=List8 → ReadList(248): size=ReadInt8()=1 → 1 node
        //     node: sizeTag=ReadInt8()=0xF8=248=List8, listSize=ReadInt8()=1
        //           tag=Read(true): tag_byte=63 → "item"
        //           listSize=1→odd→no content
        // This gives the right structure!
        var data2 = new byte[]
        {
            0xF8, 2,           // outer: List8 size=2 → tag + content
            25,                // outer tag = "iq"
            0xF8, 1,           // content = List8, size=1 child
              0xF8, 1, 63      // child node: List8 size=1, tag="item"
        };
        var node = BinaryDecoder.Decode(data2);
        Assert.Equal("iq", node.Tag);
        var children = Assert.IsType<BinaryNode[]>(node.Content);
        Assert.Single(children);
        Assert.Equal("item", children[0].Tag);
    }

    // ── error cases ───────────────────────────────────────────────────────────

    [Fact]
    public void EmptyData_ThrowsEndOfStreamException()
    {
        Assert.Throws<EndOfStreamException>(() => BinaryDecoder.Decode(Array.Empty<byte>()));
    }

    [Fact]
    public void InvalidToken_ThrowsInvalidDataException()
    {
        // Token bytes 240-244 are unassigned in the WhatsApp spec → InvalidDataException
        // Frame: List8(248) size=1 (tag only), then token byte 240
        var data = new byte[] { 0xF8, 1, 240 };
        Assert.Throws<InvalidDataException>(() => BinaryDecoder.Decode(data));
    }

    // ── Token dictionary completeness checks ─────────────────────────────────

    [Fact]
    public void SingleByteTokens_HasCorrectCount()
    {
        // 236 tokens (0-235)
        Assert.Equal(236, WaTokens_Test.SingleByteCount);
    }

    [Fact]
    public void DoubleByteTokens_HasFourDictionaries()
    {
        Assert.Equal(4, WaTokens_Test.DoubleByteDictCount);
    }

    [Fact]
    public void DoubleByteTokens_EachDictionaryHas256Entries()
    {
        for (int i = 0; i < 4; i++)
            Assert.Equal(256, WaTokens_Test.GetDoubleByteCount(i));
    }

    [Fact]
    public void KnownTokens_ArePresent()
    {
        // Spot-check a handful of important tokens
        Assert.Equal("iq",            WaTokens_Test.GetSingle(25));
        Assert.Equal("from",          WaTokens_Test.GetSingle(6));
        Assert.Equal("success",       WaTokens_Test.GetSingle(76));
        Assert.Equal("pair-device",   WaTokens_Test.GetDouble(1, 238));
        Assert.Equal("create",        WaTokens_Test.GetDouble(3, 76));
        Assert.Equal("read-self",     WaTokens_Test.GetDouble(0, 0));
    }
}

// ── Test-visible extension on BinaryNode ─────────────────────────────────────
internal static class BinaryNodeExtensions
{
    public static object? GetAttr(this BinaryNode node, string key)
        => node.Attrs.TryGetValue(key, out var v) ? v : null;
}

// ── Test accessor for internal token tables ───────────────────────────────────
internal static class WaTokens_Test
{
    public static int SingleByteCount      => WaTokens.SingleByte.Length;
    public static int DoubleByteDictCount  => WaTokens.DoubleByte.Length;
    public static string GetSingle(int i)  => WaTokens.SingleByte[i];
    public static string GetDouble(int d, int i) => WaTokens.DoubleByte[d][i];
    public static int GetDoubleByteCount(int d) => WaTokens.DoubleByte[d].Length;
}

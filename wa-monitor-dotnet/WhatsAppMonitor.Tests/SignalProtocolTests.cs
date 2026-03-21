using System.Security.Cryptography;
using libsignal;
using libsignal.ecc;
using libsignal.state;
using libsignal.util;
using WhatsAppMonitor.Protocol;
using Xunit;

namespace WhatsAppMonitor.Tests;

// ── DeviceStore clamping tests ─────────────────────────────────────────────────

public class DeviceStoreCampingTests
{
    [Fact]
    public void ClampCurve25519Seed_ClearsLow3BitsOfByte0()
    {
        byte[] seed = new byte[32];
        Array.Fill(seed, (byte)0xFF);
        byte[] clamped = DeviceStore.ClampCurve25519Seed(seed);
        Assert.Equal(0, clamped[0] & 0b00000111);
    }

    [Fact]
    public void ClampCurve25519Seed_ClearsHighBitOfByte31()
    {
        byte[] seed = new byte[32];
        Array.Fill(seed, (byte)0xFF);
        byte[] clamped = DeviceStore.ClampCurve25519Seed(seed);
        Assert.Equal(0, clamped[31] & 0b10000000);
    }

    [Fact]
    public void ClampCurve25519Seed_SetsSecondHighestBitOfByte31()
    {
        byte[] seed = new byte[32];
        byte[] clamped = DeviceStore.ClampCurve25519Seed(seed);
        Assert.NotEqual(0, clamped[31] & 0b01000000);
    }

    [Fact]
    public void ClampCurve25519Seed_DoesNotMutateInput()
    {
        byte[] seed = Enumerable.Range(0, 32).Select(i => (byte)i).ToArray();
        byte[] original = (byte[])seed.Clone();
        DeviceStore.ClampCurve25519Seed(seed);
        Assert.Equal(original, seed);
    }

    [Fact]
    public void ClampCurve25519Seed_IsIdempotent()
    {
        byte[] seed = new byte[32];
        RandomNumberGenerator.Fill(seed);
        byte[] once  = DeviceStore.ClampCurve25519Seed(seed);
        byte[] twice = DeviceStore.ClampCurve25519Seed(once);
        Assert.Equal(once, twice);
    }

    [Fact]
    public void ClampCurve25519Seed_ThrowsOnWrongLength()
    {
        Assert.Throws<ArgumentException>(() => DeviceStore.ClampCurve25519Seed(new byte[16]));
        Assert.Throws<ArgumentException>(() => DeviceStore.ClampCurve25519Seed(new byte[33]));
    }

    [Theory]
    [InlineData(0x00, 0x00)]
    [InlineData(0xFF, 0xF8)]
    [InlineData(0x07, 0x00)]
    [InlineData(0xF8, 0xF8)]
    public void ClampCurve25519Seed_Byte0ClampsCorrectly(byte input, byte expected)
    {
        byte[] seed = new byte[32];
        seed[0] = input;
        seed[31] = 0x40;
        byte[] clamped = DeviceStore.ClampCurve25519Seed(seed);
        Assert.Equal(expected, clamped[0]);
    }
}

// ── SignalProtocolStore file persistence tests ─────────────────────────────────

public class SignalProtocolStoreImplTests : IDisposable
{
    private readonly string _tempDir;

    public SignalProtocolStoreImplTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"wa-sig-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    private (DeviceStore device, SignalProtocolStoreImpl store) Build()
    {
        var device = DeviceStore.LoadOrCreate(_tempDir);
        // Each test gets its own signal-sessions sub-directory
        var signalDir = Path.Combine(_tempDir, "signal-sessions");
        var store = new SignalProtocolStoreImpl(device, signalDir);
        return (device, store);
    }

    [Fact]
    public void PreKeyStore_StoreAndLoad_RoundTrip()
    {
        var (_, store) = Build();
        var record = new PreKeyRecord(42, Curve.generateKeyPair());

        store.StorePreKey(42, record);

        Assert.True(store.ContainsPreKey(42));
        var loaded = store.LoadPreKey(42);
        Assert.Equal(42u, loaded.getId());
    }

    [Fact]
    public void PreKeyStore_Remove_DeletesKey()
    {
        var (_, store) = Build();
        var record = new PreKeyRecord(7, Curve.generateKeyPair());
        store.StorePreKey(7, record);
        store.RemovePreKey(7);
        Assert.False(store.ContainsPreKey(7));
    }

    [Fact]
    public void PreKeyStore_LoadMissing_Throws()
    {
        var (_, store) = Build();
        Assert.Throws<InvalidKeyIdException>(() => store.LoadPreKey(999));
    }

    [Fact]
    public void IdentityStore_TOFU_TrustsFreshKey()
    {
        var (_, store) = Build();
        var address  = new SignalProtocolAddress("alice@s.whatsapp.net", 0);
        var identity = KeyHelper.generateIdentityKeyPair().getPublicKey();

        Assert.True(store.IsTrustedIdentity(address, identity, Direction.RECEIVING));
    }

    [Fact]
    public void IdentityStore_AfterSave_SameKeyTrusted()
    {
        var (_, store) = Build();
        var address  = new SignalProtocolAddress("bob@s.whatsapp.net", 0);
        var identity = KeyHelper.generateIdentityKeyPair().getPublicKey();

        store.SaveIdentity(address, identity);
        Assert.True(store.IsTrustedIdentity(address, identity, Direction.RECEIVING));
    }

    [Fact]
    public void IdentityStore_AfterSave_DifferentKeyNotTrusted()
    {
        var (_, store) = Build();
        var address = new SignalProtocolAddress("charlie@s.whatsapp.net", 0);
        var key1    = KeyHelper.generateIdentityKeyPair().getPublicKey();
        var key2    = KeyHelper.generateIdentityKeyPair().getPublicKey();

        store.SaveIdentity(address, key1);
        Assert.False(store.IsTrustedIdentity(address, key2, Direction.RECEIVING));
    }

    [Fact]
    public void SessionStore_LoadMissingAddress_ReturnsFreshSession()
    {
        var (_, store) = Build();
        var address = new SignalProtocolAddress("dave@s.whatsapp.net", 0);

        var session = store.LoadSession(address);
        Assert.True(session.isFresh());
    }

    [Fact]
    public void SignedPreKeyStore_StoreAndLoad_RoundTrip()
    {
        var (_, store) = Build();
        var idPair = KeyHelper.generateIdentityKeyPair();
        var record = KeyHelper.generateSignedPreKey(idPair, 1);

        store.StoreSignedPreKey(1, record);

        Assert.True(store.ContainsSignedPreKey(1));
        var loaded = store.LoadSignedPreKey(1);
        Assert.Equal(1u, loaded.getId());
    }
}

// ── PreKeyManager tests ────────────────────────────────────────────────────────

public class PreKeyManagerTests : IDisposable
{
    private readonly string _tempDir;

    public PreKeyManagerTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"wa-pkmgr-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    private (SignalProtocolStoreImpl store, PreKeyManager manager) Build()
    {
        var device    = DeviceStore.LoadOrCreate(_tempDir);
        var signalDir = Path.Combine(_tempDir, "signal-sessions");
        var store     = new SignalProtocolStoreImpl(device, signalDir);
        var manager   = new PreKeyManager(store, baseDir: _tempDir);
        return (store, manager);
    }

    [Fact]
    public void GenerateBatch_CreatesCorrectCount()
    {
        var (_, manager) = Build();
        var records = manager.GenerateBatch(10);
        Assert.Equal(10, records.Count);
    }

    [Fact]
    public void GenerateBatch_IdsAreSequentialFromOne()
    {
        var (_, manager) = Build();
        var records = manager.GenerateBatch(5);
        for (int i = 0; i < records.Count; i++)
            Assert.Equal((uint)(i + 1), records[i].getId());
    }

    [Fact]
    public void GenerateBatch_SecondBatch_ContinuesFromLastId()
    {
        var (_, manager) = Build();
        manager.GenerateBatch(3);          // IDs 1-3
        var batch2 = manager.GenerateBatch(3); // IDs 4-6
        Assert.Equal(4u, batch2[0].getId());
        Assert.Equal(6u, batch2[2].getId());
    }

    [Fact]
    public void EnsurePoolFilled_GeneratesWhenEmpty()
    {
        var (_, manager) = Build();
        manager.EnsurePoolFilled();
        Assert.True(manager.CountAvailable() >= PreKeyManager.RefillThreshold);
    }

    [Fact]
    public void EnsurePoolFilled_SkipsWhenPoolFull()
    {
        var (_, manager) = Build();
        manager.GenerateBatch(PreKeyManager.RefillThreshold + 10);
        int countBefore = manager.CountAvailable();
        manager.EnsurePoolFilled();
        Assert.Equal(countBefore, manager.CountAvailable());
    }
}

// ── WaMessageParser tests ──────────────────────────────────────────────────────

public class WaMessageParserTests
{
    [Fact]
    public void Parse_EmptyBytes_ReturnsNull()
    {
        var parser = new WaMessageParser();
        Assert.Null(parser.Parse([]));
    }

    [Fact]
    public void Parse_ValidConversationProtobuf_ExtractsText()
    {
        string expected = "Hello, World!";
        byte[] textBytes = System.Text.Encoding.UTF8.GetBytes(expected);
        byte[] proto = BuildProtoStringField(1, textBytes);

        var parser = new WaMessageParser();
        var result = parser.Parse(proto);

        Assert.NotNull(result);
        Assert.Equal(WaMessageType.Text, result!.MessageType);
        Assert.Equal(expected, result.Conversation);
    }

    [Fact]
    public void WaDecryptedMessage_ToString_IncludesType()
    {
        var msg = new WaDecryptedMessage
        {
            MessageType  = WaMessageType.Text,
            Conversation = "test"
        };
        Assert.Contains("[text]", msg.ToString());
        Assert.Contains("test", msg.ToString());
    }

    [Fact]
    public void WaDecryptedMessage_ToString_Audio_NoConversation()
    {
        var msg = new WaDecryptedMessage { MessageType = WaMessageType.Audio };
        Assert.Contains("[audio]", msg.ToString());
    }

    private static byte[] BuildProtoStringField(int fieldNumber, byte[] value)
    {
        byte tag    = (byte)((fieldNumber << 3) | 2);
        byte len    = (byte)value.Length;
        var  result = new byte[2 + value.Length];
        result[0]   = tag;
        result[1]   = len;
        Buffer.BlockCopy(value, 0, result, 2, value.Length);
        return result;
    }
}

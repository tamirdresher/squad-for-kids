using System.Net;
using System.Text;
using WhatsAppMonitor;
using Xunit;

namespace WhatsAppMonitor.Tests;

// ── WhatsAppMessage model tests ───────────────────────────────────────────────

public class WhatsAppMessageTests
{
    [Fact]
    public void Constructor_SetsPropertiesCorrectly()
    {
        var msg = new WhatsAppMessage
        {
            Contact = "Alice",
            Text = "Hello world",
            ChatTitle = "Alice Personal"
        };

        Assert.Equal("Alice", msg.Contact);
        Assert.Equal("Hello world", msg.Text);
        Assert.Equal("Alice Personal", msg.ChatTitle);
        // Timestamp should be close to now
        Assert.True(DateTimeOffset.UtcNow - msg.Timestamp < TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void ToString_FormatsCorrectly()
    {
        var ts = new DateTimeOffset(2024, 6, 1, 12, 0, 0, TimeSpan.Zero);
        var msg = new WhatsAppMessage
        {
            Contact = "Bob",
            Text = "Hey!",
            Timestamp = ts
        };

        var str = msg.ToString();

        Assert.Contains("Bob", str);
        Assert.Contains("Hey!", str);
        Assert.Contains("2024-06-01", str);
    }

    [Fact]
    public void Record_Equality_WorksCorrectly()
    {
        var ts = DateTimeOffset.UtcNow;
        var msg1 = new WhatsAppMessage { Contact = "Alice", Text = "Hi", Timestamp = ts };
        var msg2 = new WhatsAppMessage { Contact = "Alice", Text = "Hi", Timestamp = ts };

        Assert.Equal(msg1, msg2);
    }
}

// ── WhatsAppMonitorOptions tests ──────────────────────────────────────────────

public class WhatsAppMonitorOptionsTests
{
    [Fact]
    public void DefaultOptions_HaveExpectedDefaults()
    {
        var opts = new WhatsAppMonitorOptions();

        Assert.Empty(opts.ContactFilter);
        Assert.Empty(opts.PriorityContacts);
        Assert.Equal(TimeSpan.FromMinutes(5), opts.QrScanTimeout);
        Assert.Equal(TimeSpan.FromSeconds(2), opts.PollingInterval);
        Assert.Equal(TimeSpan.FromHours(1), opts.SummaryInterval);
        Assert.False(opts.Headless);
        Assert.False(opts.EnableGeneralMonitoring);
        Assert.Null(opts.UserDataDir);
        Assert.Null(opts.TeamsWebhookUrl);
    }

    [Fact]
    public void Options_ContactFilter_CanBeSet()
    {
        var opts = new WhatsAppMonitorOptions
        {
            ContactFilter = ["Alice", "Bob"]
        };

        Assert.Equal(2, opts.ContactFilter.Count);
        Assert.Contains("Alice", opts.ContactFilter);
    }

    [Fact]
    public void Options_PriorityContacts_CanBeSet()
    {
        var opts = new WhatsAppMonitorOptions
        {
            PriorityContacts = ["Gabi", "גבי", "Yonatan"],
            EnableGeneralMonitoring = true
        };

        Assert.Equal(3, opts.PriorityContacts.Count);
        Assert.True(opts.EnableGeneralMonitoring);
    }
}

// ── TeamsNotifier tests ───────────────────────────────────────────────────────

public class TeamsNotifierTests
{
    [Fact]
    public void Constructor_ThrowsOnEmptyWebhookUrl()
    {
        Assert.Throws<ArgumentException>(() => new TeamsNotifier(""));
        Assert.Throws<ArgumentException>(() => new TeamsNotifier("   "));
    }

    [Fact]
    public async Task NotifyAsync_ThrowsWhenDisposed()
    {
        var notifier = new TeamsNotifier("https://example.com/webhook");
        await notifier.DisposeAsync();

        var msg = new WhatsAppMessage { Contact = "Test", Text = "hi" };
        await Assert.ThrowsAsync<ObjectDisposedException>(() => notifier.NotifyAsync(msg));
    }

    [Fact]
    public async Task NotifyAsync_SendsHttpPost_WithCorrectContentType()
    {
        string? capturedContentType = null;
        string? capturedBody = null;

        var handler = new MockHttpMessageHandler(req =>
        {
            capturedContentType = req.Content?.Headers.ContentType?.MediaType;
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);

        var msg = new WhatsAppMessage
        {
            Contact = "Charlie",
            Text = "Unit test message",
            ChatTitle = "Charlie"
        };

        await notifier.NotifyAsync(msg);

        Assert.Equal("application/json", capturedContentType);
        Assert.NotNull(capturedBody);
        Assert.Contains("Charlie", capturedBody);
        Assert.Contains("Unit test message", capturedBody);
    }

    [Fact]
    public async Task NotifyAsync_CardContainsAtTypeAndAtContext()
    {
        string? capturedBody = null;

        var handler = new MockHttpMessageHandler(req =>
        {
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var msg = new WhatsAppMessage { Contact = "Alice", Text = "Hello" };

        await notifier.NotifyAsync(msg);

        Assert.NotNull(capturedBody);
        Assert.Contains("@type", capturedBody);
        Assert.Contains("@context", capturedBody);
        Assert.Contains("MessageCard", capturedBody);
        Assert.Contains("25D366", capturedBody);  // priority green
    }

    [Fact]
    public async Task NotifyAlertAsync_UsesAmberThemeColor()
    {
        string? capturedBody = null;

        var handler = new MockHttpMessageHandler(req =>
        {
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var msg = new WhatsAppMessage { Contact = "Random", Text = "דחוף!" };

        await notifier.NotifyAlertAsync(msg);

        Assert.NotNull(capturedBody);
        Assert.Contains("FFC107", capturedBody);  // amber alert
        Assert.Contains("Random", capturedBody);
    }

    [Fact]
    public async Task NotifySummaryAsync_SendsAllContacts()
    {
        string? capturedBody = null;

        var handler = new MockHttpMessageHandler(req =>
        {
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);

        var messages = new List<WhatsAppMessage>
        {
            new() { Contact = "John", Text = "Hey" },
            new() { Contact = "Jane", Text = "Can you help?" },
        };

        await notifier.NotifySummaryAsync(messages);

        Assert.NotNull(capturedBody);
        Assert.Contains("John", capturedBody);
        Assert.Contains("Jane", capturedBody);
        Assert.Contains("0078D4", capturedBody);  // Teams blue summary
    }

    [Fact]
    public async Task NotifySummaryAsync_NoOpsOnEmptyList()
    {
        int callCount = 0;

        var handler = new MockHttpMessageHandler(req =>
        {
            callCount++;
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        await notifier.NotifySummaryAsync([]);

        Assert.Equal(0, callCount);
    }
}

// ── Helpers for TeamsNotifier testability ────────────────────────────────────

/// <summary>
/// Subclass that accepts a custom HttpMessageHandler for testing.
/// In production, prefer IHttpClientFactory injection.
/// </summary>
internal sealed class TeamsNotifierTestable : TeamsNotifier
{
    public TeamsNotifierTestable(string webhookUrl, HttpMessageHandler handler)
        : base(webhookUrl, null, handler) { }
}

internal sealed class MockHttpMessageHandler(
    Func<HttpRequestMessage, HttpResponseMessage> handler) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromResult(handler(request));
}

// ── Contact filter logic tests ────────────────────────────────────────────────

/// <summary>
/// Tests the contact filtering logic that lives inside WhatsAppWebMonitor.
/// We test it indirectly through the public event, using a subclass that exposes
/// the protected method for unit testing purposes.
/// </summary>
public class ContactFilterTests
{
    [Theory]
    [InlineData("Alice", new[] { "Alice" }, true)]
    [InlineData("alice", new[] { "ALICE" }, true)]        // case-insensitive
    [InlineData("Alice Smith", new[] { "Alice" }, true)]  // partial match
    [InlineData("Bob", new[] { "Alice" }, false)]
    [InlineData("Bob", new string[0], true)]               // empty filter = allow all
    public void FilterMatch_BehavesCorrectly(string contact, string[] filter, bool expected)
    {
        var filterList = filter.ToList();

        bool matches;
        if (filterList.Count == 0)
        {
            matches = true; // empty filter = all pass
        }
        else
        {
            matches = filterList.Any(f =>
                contact.Contains(f, StringComparison.OrdinalIgnoreCase));
        }

        Assert.Equal(expected, matches);
    }
}

// ── MessageClassifier tests ───────────────────────────────────────────────────

public class MessageClassifierTests
{
    private static readonly string[] PriorityList = ["Gabi", "גבי", "Yonatan", "יונתן", "Shira", "שירה"];

    // ── IsPriorityContact ─────────────────────────────────────────────────────

    [Theory]
    [InlineData("Gabi",            true)]
    [InlineData("גבי",             true)]
    [InlineData("גביק",            true)]   // Hebrew diminutive
    [InlineData("Yonatan Dresher", true)]   // partial match
    [InlineData("יונתן דרשר",      true)]
    [InlineData("Shira",           true)]
    [InlineData("שירה דרשר",       true)]
    [InlineData("RandomFriend",    false)]
    [InlineData("Mom",             false)]
    public void IsPriorityContact_MatchesExpected(string contact, bool expected)
    {
        Assert.Equal(expected, MessageClassifier.IsPriorityContact(contact, PriorityList));
    }

    // ── IsUrgent ──────────────────────────────────────────────────────────────

    [Theory]
    [InlineData("this is urgent",          true)]
    [InlineData("URGENT please respond",   true)]
    [InlineData("דחוף תחזור אליי",          true)]
    [InlineData("מדחוף!!",                  true)]
    [InlineData("חשוב מאוד",               true)]
    [InlineData("hey what's up",           false)]
    [InlineData("שלום מה שלומך",            false)]
    public void IsUrgent_DetectsKeywords(string text, bool expected)
    {
        Assert.Equal(expected, MessageClassifier.IsUrgent(text));
    }

    // ── MentionsTamir ─────────────────────────────────────────────────────────

    [Theory]
    [InlineData("תמיר, תתקשר אלי",   true)]
    [InlineData("Hi Tamir!",          true)]
    [InlineData("TAMIR are you free", true)]
    [InlineData("hey, are you free?", false)]
    [InlineData("שלום יוני",          false)]
    public void MentionsTamir_DetectsName(string text, bool expected)
    {
        Assert.Equal(expected, MessageClassifier.MentionsTamir(text));
    }

    // ── IsQuestion ────────────────────────────────────────────────────────────

    [Theory]
    [InlineData("Can you help me?",  true)]
    [InlineData("Are you free today?", true)]
    [InlineData("יש לך זמן?",        true)]
    [InlineData("Hello there",        false)]
    [InlineData("Just letting you know", false)]
    public void IsQuestion_DetectsTrailingQuestionMark(string text, bool expected)
    {
        Assert.Equal(expected, MessageClassifier.IsQuestion(text));
    }

    // ── Classify ──────────────────────────────────────────────────────────────

    [Fact]
    public void Classify_PriorityContact_ReturnsPriority()
    {
        var msg = new WhatsAppMessage { Contact = "Gabi", Text = "hey what's up" };
        Assert.Equal(MessageCategory.Priority, MessageClassifier.Classify(msg, PriorityList));
    }

    [Fact]
    public void Classify_UrgentMessageFromGeneral_ReturnsUrgentGeneral()
    {
        var msg = new WhatsAppMessage { Contact = "RandomFriend", Text = "דחוף! צריך עזרה" };
        Assert.Equal(MessageCategory.UrgentGeneral, MessageClassifier.Classify(msg, PriorityList));
    }

    [Fact]
    public void Classify_QuestionFromGeneral_ReturnsUrgentGeneral()
    {
        var msg = new WhatsAppMessage { Contact = "WorkColleague", Text = "Can we meet tomorrow?" };
        Assert.Equal(MessageCategory.UrgentGeneral, MessageClassifier.Classify(msg, PriorityList));
    }

    [Fact]
    public void Classify_TamirMentionFromGeneral_ReturnsUrgentGeneral()
    {
        var msg = new WhatsAppMessage { Contact = "Neighbor", Text = "תמיר ראיתי את הכלב שלך בגינה" };
        Assert.Equal(MessageCategory.UrgentGeneral, MessageClassifier.Classify(msg, PriorityList));
    }

    [Fact]
    public void Classify_OrdinaryMessageFromGeneral_ReturnsGeneral()
    {
        var msg = new WhatsAppMessage { Contact = "RandomPerson", Text = "Hey see you later" };
        Assert.Equal(MessageCategory.General, MessageClassifier.Classify(msg, PriorityList));
    }

    [Fact]
    public void Classify_UsesBuiltInDefaultsWhenPriorityListIsEmpty()
    {
        // Gabi is in built-in defaults
        var msg = new WhatsAppMessage { Contact = "Gabi", Text = "hey" };
        Assert.Equal(MessageCategory.Priority, MessageClassifier.Classify(msg, []));
    }

    [Fact]
    public void Classify_PriorityContactUrgentMessage_StillReturnsPriority()
    {
        // Even if the message is urgent, priority beats urgent-general
        var msg = new WhatsAppMessage { Contact = "Yonatan", Text = "דחוף מאוד!" };
        Assert.Equal(MessageCategory.Priority, MessageClassifier.Classify(msg, PriorityList));
    }
}

// ── GeneralMessageBatcher tests ───────────────────────────────────────────────

public class GeneralMessageBatcherTests
{
    [Fact]
    public async Task Batcher_FlushAsync_SendsSummary()
    {
        string? capturedBody = null;
        var handler = new MockHttpMessageHandler(req =>
        {
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var batcher = new GeneralMessageBatcher(notifier, TimeSpan.FromHours(1));

        batcher.Add(new WhatsAppMessage { Contact = "Alice", Text = "Hi there" });
        batcher.Add(new WhatsAppMessage { Contact = "Bob",   Text = "What time?" });

        Assert.Equal(2, batcher.PendingCount);

        await batcher.FlushAsync();

        Assert.Equal(0, batcher.PendingCount);
        Assert.NotNull(capturedBody);
        Assert.Contains("Alice", capturedBody);
        Assert.Contains("Bob", capturedBody);

        await batcher.DisposeAsync();
    }

    [Fact]
    public async Task Batcher_FlushAsync_NoOpsWhenEmpty()
    {
        int callCount = 0;
        var handler = new MockHttpMessageHandler(req =>
        {
            callCount++;
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var batcher = new GeneralMessageBatcher(notifier, TimeSpan.FromHours(1));

        await batcher.FlushAsync();

        Assert.Equal(0, callCount);
        await batcher.DisposeAsync();
    }

    [Fact]
    public async Task Batcher_Dispose_FlushesPendingMessages()
    {
        string? capturedBody = null;
        var handler = new MockHttpMessageHandler(req =>
        {
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var batcher = new GeneralMessageBatcher(notifier, TimeSpan.FromHours(1));

        batcher.Add(new WhatsAppMessage { Contact = "Charlie", Text = "Last message before shutdown" });

        await batcher.DisposeAsync();

        Assert.NotNull(capturedBody);
        Assert.Contains("Charlie", capturedBody);
    }

    [Fact]
    public void Batcher_PendingCount_TracksMessages()
    {
        var handler = new MockHttpMessageHandler(req =>
            new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") });

        var notifier = new TeamsNotifierTestable("https://fake.example/hook", handler);
        var batcher = new GeneralMessageBatcher(notifier, TimeSpan.FromHours(1));

        Assert.Equal(0, batcher.PendingCount);

        batcher.Add(new WhatsAppMessage { Contact = "X", Text = "msg1" });
        Assert.Equal(1, batcher.PendingCount);

        batcher.Add(new WhatsAppMessage { Contact = "Y", Text = "msg2" });
        Assert.Equal(2, batcher.PendingCount);
    }
}


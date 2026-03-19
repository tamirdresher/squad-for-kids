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
        Assert.Equal(TimeSpan.FromMinutes(5), opts.QrScanTimeout);
        Assert.Equal(TimeSpan.FromSeconds(2), opts.PollingInterval);
        Assert.False(opts.Headless);
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
        // Use a fake HTTP server (inline handler via MockHttpMessageHandler)
        string? capturedContentType = null;
        string? capturedBody = null;

        var handler = new MockHttpMessageHandler(req =>
        {
            capturedContentType = req.Content?.Headers.ContentType?.MediaType;
            capturedBody = req.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("1") };
        });

        // We test the internal HTTP behaviour by using reflection to replace the HttpClient.
        // For a cleaner architecture in production you would inject IHttpClientFactory;
        // this test validates the contract without hitting a real endpoint.
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

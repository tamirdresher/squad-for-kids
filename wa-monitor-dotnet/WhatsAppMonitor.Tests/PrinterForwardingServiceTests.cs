using System.Net;
using WhatsAppMonitor;
using Xunit;

namespace WhatsAppMonitor.Tests;

// ── ShouldForward logic tests ──────────────────────────────────────────────────

public class PrinterForwardingServiceTests
{
    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PrinterForwardingService BuildService(
        string[]? priorityContacts = null,
        string[]? keywords = null) =>
        new(new PrinterForwardingOptions
        {
            PriorityContacts = priorityContacts ?? ["Gabi", "Yonatan Dresher", "Shira Dresher"],
            PrintKeywords    = keywords          ?? ["print", "הדפסה", "מדפסת", "תדפיס", "להדפיס"],
            SmtpCredentialTarget = "wa-monitor-gmail-TEST",  // won't be looked up in unit tests
            SmtpPasswordEnvVar   = "__WA_MONITOR_TEST_PW__"  // non-existent env var
        });

    private static WhatsAppMessage Msg(string contact, string text,
        bool hasAttachment = false, string? attachmentFileName = null) =>
        new()
        {
            Contact            = contact,
            Text               = text,
            HasAttachment      = hasAttachment,
            AttachmentFileName = attachmentFileName
        };

    // ── ShouldForward — positive cases ──────────────────────────────────────

    [Fact]
    public void ShouldForward_PriorityContact_EnglishKeyword_ReturnsTrue()
    {
        var svc = BuildService();
        Assert.True(svc.ShouldForward(Msg("Gabi", "please print this document")));
    }

    [Fact]
    public void ShouldForward_PriorityContact_HebrewKeyword_ReturnsTrue()
    {
        var svc = BuildService();
        Assert.True(svc.ShouldForward(Msg("Yonatan Dresher", "צריך הדפסה של המסמך")));
    }

    [Fact]
    public void ShouldForward_PriorityContact_HebrewMadpeset_ReturnsTrue()
    {
        var svc = BuildService();
        Assert.True(svc.ShouldForward(Msg("Shira Dresher", "שלח למדפסת")));
    }

    [Fact]
    public void ShouldForward_PriorityContact_HebrewTadpis_ReturnsTrue()
    {
        var svc = BuildService();
        Assert.True(svc.ShouldForward(Msg("Gabi", "תדפיס בבקשה")));
    }

    [Fact]
    public void ShouldForward_PriorityContact_HebrewLeHadpis_ReturnsTrue()
    {
        var svc = BuildService();
        Assert.True(svc.ShouldForward(Msg("Shira Dresher", "צריך להדפיס")));
    }

    [Fact]
    public void ShouldForward_KeywordInAttachmentFileName_ReturnsTrue()
    {
        var svc = BuildService();
        // text doesn't have the keyword, but the file name does
        var msg = Msg("Gabi", "here is the file",
            hasAttachment: true, attachmentFileName: "report-to-print.pdf");
        Assert.True(svc.ShouldForward(msg));
    }

    [Fact]
    public void ShouldForward_CaseInsensitiveContactAndKeyword_ReturnsTrue()
    {
        var svc = BuildService();
        // Both the contact name and the keyword use different casing
        Assert.True(svc.ShouldForward(Msg("YONATAN DRESHER", "PRINT this")));
    }

    [Fact]
    public void ShouldForward_PartialContactMatch_ReturnsTrue()
    {
        var svc = BuildService();
        // "Gabi Cohen" contains "Gabi"
        Assert.True(svc.ShouldForward(Msg("Gabi Cohen", "please print")));
    }

    // ── ShouldForward — negative cases ──────────────────────────────────────

    [Fact]
    public void ShouldForward_NonPriorityContact_ReturnsFalse()
    {
        var svc = BuildService();
        Assert.False(svc.ShouldForward(Msg("Random Person", "please print this")));
    }

    [Fact]
    public void ShouldForward_PriorityContactWithoutKeyword_ReturnsFalse()
    {
        var svc = BuildService();
        Assert.False(svc.ShouldForward(Msg("Gabi", "how are you doing today?")));
    }

    [Fact]
    public void ShouldForward_AttachmentFromNonPriorityContact_ReturnsFalse()
    {
        var svc = BuildService();
        var msg = Msg("Unknown User", "sending file",
            hasAttachment: true, attachmentFileName: "print-me.pdf");
        Assert.False(svc.ShouldForward(msg));
    }

    // ── ResolveSmtpPassword ──────────────────────────────────────────────────

    [Fact]
    public void ResolveSmtpPassword_EnvVarFallback_ReturnsValue()
    {
        const string envVar = "__WA_MONITOR_TEST_PW_UNIQUE__";
        const string expected = "testpassword123";

        try
        {
            Environment.SetEnvironmentVariable(envVar, expected);

            var svc = new PrinterForwardingService(new PrinterForwardingOptions
            {
                SmtpCredentialTarget = "no-such-target-in-credman",
                SmtpPasswordEnvVar   = envVar
            });

            var result = svc.ResolveSmtpPassword();
            Assert.Equal(expected, result);
        }
        finally
        {
            Environment.SetEnvironmentVariable(envVar, null);
        }
    }

    [Fact]
    public void ResolveSmtpPassword_NoSourceConfigured_ReturnsNull()
    {
        const string envVar = "__WA_MONITOR_NOT_SET_EVER__";
        Environment.SetEnvironmentVariable(envVar, null); // ensure absent

        var svc = new PrinterForwardingService(new PrinterForwardingOptions
        {
            SmtpCredentialTarget = "no-such-credential-target",
            SmtpPasswordEnvVar   = envVar
        });

        Assert.Null(svc.ResolveSmtpPassword());
    }

    // ── TryForwardToPrinterAsync — skip when ShouldForward is false ──────────

    [Fact]
    public async Task TryForwardToPrinterAsync_NonMatchingMessage_ReturnsFalse()
    {
        var svc = BuildService();
        var msg = Msg("Nobody Important", "just chatting");

        // No page, no SMTP configured — but ShouldForward is false so nothing is attempted
        var result = await svc.TryForwardToPrinterAsync(msg, page: null);
        Assert.False(result);
    }

    [Fact]
    public async Task TryForwardToPrinterAsync_ThrowsWhenDisposed()
    {
        var svc = BuildService();
        await svc.DisposeAsync();

        var msg = Msg("Gabi", "print this");
        await Assert.ThrowsAsync<ObjectDisposedException>(
            () => svc.TryForwardToPrinterAsync(msg));
    }

    // ── PrinterForwardingOptions defaults ────────────────────────────────────

    [Fact]
    public void Options_DefaultPriorityContacts_ContainsExpectedNames()
    {
        var opts = new PrinterForwardingOptions();
        Assert.Contains("Gabi",           opts.PriorityContacts);
        Assert.Contains("Yonatan Dresher", opts.PriorityContacts);
        Assert.Contains("Shira Dresher",  opts.PriorityContacts);
    }

    [Fact]
    public void Options_DefaultKeywords_ContainsBothEnglishAndHebrew()
    {
        var opts = new PrinterForwardingOptions();
        Assert.Contains("print",    opts.PrintKeywords);
        Assert.Contains("הדפסה",  opts.PrintKeywords);
        Assert.Contains("מדפסת",  opts.PrintKeywords);
        Assert.Contains("תדפיס",  opts.PrintKeywords);
        Assert.Contains("להדפיס", opts.PrintKeywords);
    }

    [Fact]
    public void Options_DefaultPrinterEmail_IsHpePrint()
    {
        var opts = new PrinterForwardingOptions();
        Assert.Equal("dresherhome@hpeprint.com", opts.PrinterEmailAddress);
    }

    [Fact]
    public void Options_DefaultSmtp_IsGmail()
    {
        var opts = new PrinterForwardingOptions();
        Assert.Equal("smtp.gmail.com",     opts.SmtpHost);
        Assert.Equal(587,                  opts.SmtpPort);
        Assert.Equal("tdsquadai@gmail.com", opts.SmtpUser);
    }

    [Fact]
    public void Options_DefaultCredentialTarget_IsExpected()
    {
        var opts = new PrinterForwardingOptions();
        Assert.Equal("wa-monitor-gmail",          opts.SmtpCredentialTarget);
        Assert.Equal("WA_MONITOR_SMTP_PASSWORD",  opts.SmtpPasswordEnvVar);
    }
}

// ── WhatsAppMessage attachment fields ─────────────────────────────────────────

public class WhatsAppMessageAttachmentTests
{
    [Fact]
    public void WhatsAppMessage_AttachmentFields_DefaultToFalseAndNull()
    {
        var msg = new WhatsAppMessage { Contact = "Alice", Text = "Hello" };
        Assert.False(msg.HasAttachment);
        Assert.Null(msg.AttachmentType);
        Assert.Null(msg.AttachmentFileName);
    }

    [Fact]
    public void WhatsAppMessage_AttachmentFields_CanBeSet()
    {
        var msg = new WhatsAppMessage
        {
            Contact            = "Bob",
            Text               = "Here is the document",
            HasAttachment      = true,
            AttachmentType     = "doc",
            AttachmentFileName = "invoice.pdf"
        };

        Assert.True(msg.HasAttachment);
        Assert.Equal("doc",          msg.AttachmentType);
        Assert.Equal("invoice.pdf",  msg.AttachmentFileName);
    }

    [Fact]
    public void WhatsAppMessage_ToString_IncludesAttachmentTag_WhenPresent()
    {
        var msg = new WhatsAppMessage
        {
            Contact       = "Carol",
            Text          = "check this out",
            HasAttachment = true,
            AttachmentType = "doc"
        };

        Assert.Contains("doc", msg.ToString());
    }

    [Fact]
    public void WhatsAppMessage_ToString_NoAttachmentTag_WhenAbsent()
    {
        var msg = new WhatsAppMessage { Contact = "Dave", Text = "Hi there" };
        var str = msg.ToString();

        // Should not contain attachment marker
        Assert.DoesNotContain("attachment", str, StringComparison.OrdinalIgnoreCase);
    }
}

// ── WhatsAppMonitorOptions printer forwarding ──────────────────────────────────

public class WhatsAppMonitorOptionsPrinterTests
{
    [Fact]
    public void MonitorOptions_PrinterForwarding_DefaultsToNull()
    {
        var opts = new WhatsAppMonitorOptions();
        Assert.Null(opts.PrinterForwarding);
    }

    [Fact]
    public void MonitorOptions_PrinterForwarding_CanBeSet()
    {
        var printerOpts = new PrinterForwardingOptions();
        var opts = new WhatsAppMonitorOptions { PrinterForwarding = printerOpts };
        Assert.Same(printerOpts, opts.PrinterForwarding);
    }
}

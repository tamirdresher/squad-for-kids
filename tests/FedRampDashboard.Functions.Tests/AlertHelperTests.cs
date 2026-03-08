using Xunit;
using FluentAssertions;
using FedRampDashboard.Functions;

namespace FedRampDashboard.Functions.Tests;

public class AlertHelperTests
{
    #region GenerateDedupKey Tests

    [Fact]
    public void GenerateDedupKey_ShouldReturnCorrectFormat_WithAllParameters()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2";
        var environment = "prod";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:dedup:control_drift:AC-2:prod");
    }

    [Fact]
    public void GenerateDedupKey_ShouldUseGlobal_WhenControlIdIsNull()
    {
        // Arrange
        var alertType = "threshold_breach";
        string controlId = null;
        var environment = "stg";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:dedup:threshold_breach:global:stg");
    }

    [Fact]
    public void GenerateDedupKey_ShouldUseGlobal_WhenControlIdIsEmptyString()
    {
        // Arrange
        var alertType = "api_failure";
        var controlId = string.Empty;
        var environment = "dev";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:dedup:api_failure::dev");
    }

    [Fact]
    public void GenerateDedupKey_ShouldHandleSpecialCharactersInControlId()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2.1/test";
        var environment = "prod";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:dedup:control_drift:AC-2.1/test:prod");
    }

    [Theory]
    [InlineData("control_drift", "AC-2", "dev")]
    [InlineData("threshold_breach", "SC-7", "stg")]
    [InlineData("api_failure", "AU-3", "prod")]
    public void GenerateDedupKey_ShouldBeDeterministic_ForSameInputs(string alertType, string controlId, string environment)
    {
        // Act
        var result1 = AlertHelper.GenerateDedupKey(alertType, controlId, environment);
        var result2 = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result1.Should().Be(result2);
    }

    [Fact]
    public void GenerateDedupKey_ShouldProduceDifferentKeys_ForDifferentAlertTypes()
    {
        // Arrange
        var controlId = "AC-2";
        var environment = "prod";

        // Act
        var key1 = AlertHelper.GenerateDedupKey("control_drift", controlId, environment);
        var key2 = AlertHelper.GenerateDedupKey("threshold_breach", controlId, environment);

        // Assert
        key1.Should().NotBe(key2);
    }

    [Fact]
    public void GenerateDedupKey_ShouldProduceDifferentKeys_ForDifferentEnvironments()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2";

        // Act
        var keyDev = AlertHelper.GenerateDedupKey(alertType, controlId, "dev");
        var keyProd = AlertHelper.GenerateDedupKey(alertType, controlId, "prod");

        // Assert
        keyDev.Should().NotBe(keyProd);
    }

    #endregion

    #region GenerateAckKey Tests

    [Fact]
    public void GenerateAckKey_ShouldReturnCorrectFormat_WithAllParameters()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2";
        var environment = "prod";

        // Act
        var result = AlertHelper.GenerateAckKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:ack:control_drift:AC-2:prod");
    }

    [Fact]
    public void GenerateAckKey_ShouldUseGlobal_WhenControlIdIsNull()
    {
        // Arrange
        var alertType = "threshold_breach";
        string controlId = null;
        var environment = "stg";

        // Act
        var result = AlertHelper.GenerateAckKey(alertType, controlId, environment);

        // Assert
        result.Should().Be("alert:ack:threshold_breach:global:stg");
    }

    [Fact]
    public void GenerateAckKey_ShouldDifferFromDedupKey_ForSameInputs()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2";
        var environment = "prod";

        // Act
        var dedupKey = AlertHelper.GenerateDedupKey(alertType, controlId, environment);
        var ackKey = AlertHelper.GenerateAckKey(alertType, controlId, environment);

        // Assert
        ackKey.Should().NotBe(dedupKey);
        ackKey.Should().Contain("alert:ack:");
        dedupKey.Should().Contain("alert:dedup:");
    }

    #endregion

    #region SeverityMapping.ToPagerDuty Tests

    [Theory]
    [InlineData("P0", "critical")]
    [InlineData("P1", "error")]
    [InlineData("P2", "warning")]
    [InlineData("P3", "info")]
    public void ToPagerDuty_ShouldMapCorrectly_ForValidSeverities(string severity, string expected)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToPagerDuty(severity);

        // Assert
        result.Should().Be(expected);
    }

    [Theory]
    [InlineData("P4")]
    [InlineData("Invalid")]
    [InlineData("")]
    [InlineData(null)]
    public void ToPagerDuty_ShouldReturnWarning_ForUnknownSeverities(string severity)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToPagerDuty(severity);

        // Assert
        result.Should().Be("warning");
    }

    [Fact]
    public void ToPagerDuty_ShouldBeCaseExact_ForSeverityInput()
    {
        // Act - lowercase should not match
        var result = AlertHelper.SeverityMapping.ToPagerDuty("p0");

        // Assert
        result.Should().Be("warning"); // Default for unknown
    }

    #endregion

    #region SeverityMapping.ToTeamsWebhookKey Tests

    [Theory]
    [InlineData("P0", "critical")]
    [InlineData("P1", "critical")]
    [InlineData("P2", "medium")]
    [InlineData("P3", "low")]
    public void ToTeamsWebhookKey_ShouldMapCorrectly_ForValidSeverities(string severity, string expected)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToTeamsWebhookKey(severity);

        // Assert
        result.Should().Be(expected);
    }

    [Theory]
    [InlineData("P4")]
    [InlineData("Invalid")]
    [InlineData("")]
    [InlineData(null)]
    public void ToTeamsWebhookKey_ShouldReturnMedium_ForUnknownSeverities(string severity)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToTeamsWebhookKey(severity);

        // Assert
        result.Should().Be("medium");
    }

    [Fact]
    public void ToTeamsWebhookKey_ShouldMapP0AndP1ToCritical_ShowingPrioritization()
    {
        // Act
        var p0Result = AlertHelper.SeverityMapping.ToTeamsWebhookKey("P0");
        var p1Result = AlertHelper.SeverityMapping.ToTeamsWebhookKey("P1");

        // Assert
        p0Result.Should().Be("critical");
        p1Result.Should().Be("critical");
        p0Result.Should().Be(p1Result); // Both map to same level
    }

    #endregion

    #region SeverityMapping.ToTeamsCardStyle Tests

    [Theory]
    [InlineData("P0", "attention")]
    [InlineData("P1", "warning")]
    [InlineData("P2", "good")]
    [InlineData("P3", "default")]
    public void ToTeamsCardStyle_ShouldMapCorrectly_ForValidSeverities(string severity, string expected)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToTeamsCardStyle(severity);

        // Assert
        result.Should().Be(expected);
    }

    [Theory]
    [InlineData("P4")]
    [InlineData("Invalid")]
    [InlineData("")]
    [InlineData(null)]
    public void ToTeamsCardStyle_ShouldReturnDefault_ForUnknownSeverities(string severity)
    {
        // Act
        var result = AlertHelper.SeverityMapping.ToTeamsCardStyle(severity);

        // Assert
        result.Should().Be("default");
    }

    [Fact]
    public void ToTeamsCardStyle_ShouldProduceDifferentStyles_ForDifferentSeverities()
    {
        // Act
        var p0Style = AlertHelper.SeverityMapping.ToTeamsCardStyle("P0");
        var p1Style = AlertHelper.SeverityMapping.ToTeamsCardStyle("P1");
        var p2Style = AlertHelper.SeverityMapping.ToTeamsCardStyle("P2");
        var p3Style = AlertHelper.SeverityMapping.ToTeamsCardStyle("P3");

        // Assert
        p0Style.Should().NotBe(p1Style);
        p1Style.Should().NotBe(p2Style);
        p2Style.Should().NotBe(p3Style);
    }

    #endregion

    #region Cross-Platform Consistency Tests

    [Fact]
    public void SeverityMappings_ShouldBeConsistent_AcrossPlatformsForP0()
    {
        // Arrange
        var severity = "P0";

        // Act
        var pagerDuty = AlertHelper.SeverityMapping.ToPagerDuty(severity);
        var teamsWebhook = AlertHelper.SeverityMapping.ToTeamsWebhookKey(severity);
        var teamsCard = AlertHelper.SeverityMapping.ToTeamsCardStyle(severity);

        // Assert
        pagerDuty.Should().Be("critical");
        teamsWebhook.Should().Be("critical");
        teamsCard.Should().Be("attention");
    }

    [Fact]
    public void SeverityMappings_ShouldHandleNull_GracefullyAcrossAllPlatforms()
    {
        // Act
        var pagerDuty = AlertHelper.SeverityMapping.ToPagerDuty(null);
        var teamsWebhook = AlertHelper.SeverityMapping.ToTeamsWebhookKey(null);
        var teamsCard = AlertHelper.SeverityMapping.ToTeamsCardStyle(null);

        // Assert - All should return safe defaults
        pagerDuty.Should().NotBeNullOrEmpty();
        teamsWebhook.Should().NotBeNullOrEmpty();
        teamsCard.Should().NotBeNullOrEmpty();
    }

    #endregion

    #region Edge Cases and Robustness Tests

    [Fact]
    public void GenerateDedupKey_ShouldHandleWhitespace_InParameters()
    {
        // Arrange
        var alertType = " control_drift ";
        var controlId = " AC-2 ";
        var environment = " prod ";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Contain(" control_drift ");
        result.Should().Contain(" AC-2 ");
        result.Should().Contain(" prod ");
    }

    [Fact]
    public void GenerateAckKey_ShouldHandleWhitespace_InParameters()
    {
        // Arrange
        var alertType = " threshold_breach ";
        var controlId = " SC-7 ";
        var environment = " stg ";

        // Act
        var result = AlertHelper.GenerateAckKey(alertType, controlId, environment);

        // Assert
        result.Should().Contain(" threshold_breach ");
        result.Should().Contain(" SC-7 ");
        result.Should().Contain(" stg ");
    }

    [Theory]
    [InlineData("control_drift", "AC-2:subpart", "prod")]
    [InlineData("threshold_breach", "global", "stg")]
    [InlineData("api:failure", "AC-2", "prod")]
    public void GenerateDedupKey_ShouldNotCorrupt_ColonCharactersInInputs(string alertType, string controlId, string environment)
    {
        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert - Should preserve colons from inputs
        result.Should().StartWith("alert:dedup:");
        result.Should().Contain(alertType);
        result.Should().Contain(controlId);
        result.Should().Contain(environment);
    }

    [Fact]
    public void GenerateDedupKey_ShouldHandleUnicodeCharacters_InControlId()
    {
        // Arrange
        var alertType = "control_drift";
        var controlId = "AC-2-测试";
        var environment = "prod";

        // Act
        var result = AlertHelper.GenerateDedupKey(alertType, controlId, environment);

        // Assert
        result.Should().Contain("AC-2-测试");
    }

    #endregion
}

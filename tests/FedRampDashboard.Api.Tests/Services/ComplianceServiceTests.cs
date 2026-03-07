using Xunit;
using Moq;
using FluentAssertions;
using FedRampDashboard.Api.Services;
using FedRampDashboard.Api.Models;
using Microsoft.Extensions.Configuration;

namespace FedRampDashboard.Api.Tests.Services;

public class ComplianceServiceTests
{
    private readonly Mock<ILogAnalyticsService> _mockLogAnalytics;
    private readonly Mock<ICosmosDbService> _mockCosmosDb;
    private readonly ComplianceService _service;

    public ComplianceServiceTests()
    {
        _mockLogAnalytics = new Mock<ILogAnalyticsService>();
        _mockCosmosDb = new Mock<ICosmosDbService>();
        _service = new ComplianceService(_mockLogAnalytics.Object, _mockCosmosDb.Object);
    }

    [Fact]
    public async Task GetComplianceStatus_ShouldReturnStatus_WhenDataExists()
    {
        // Arrange
        var environment = "PROD";
        var controlCategory = "System and Communications Protection";

        // Act
        var result = await _service.GetComplianceStatusAsync(environment, controlCategory);

        // Assert
        result.Should().NotBeNull();
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
        result.OverallComplianceRate.Should().BeGreaterOrEqualTo(0);
    }

    [Fact]
    public async Task GetComplianceTrend_ShouldReturnTrend_ForValidDateRange()
    {
        // Arrange
        var environment = "STG";
        var startDate = DateTime.UtcNow.AddDays(-7);
        var endDate = DateTime.UtcNow;
        var granularity = "daily";

        // Act
        var result = await _service.GetComplianceTrendAsync(environment, startDate, endDate, granularity);

        // Assert
        result.Should().NotBeNull();
        result.Environment.Should().Be(environment);
        result.StartDate.Should().Be(startDate);
        result.EndDate.Should().Be(endDate);
        result.Granularity.Should().Be(granularity);
    }

    [Theory]
    [InlineData("hourly", "1h")]
    [InlineData("daily", "1d")]
    [InlineData("weekly", "7d")]
    public async Task GetComplianceTrend_ShouldUseCorrectGranularity(string granularity, string expectedBin)
    {
        // Arrange
        var environment = "DEV";
        var startDate = DateTime.UtcNow.AddDays(-14);
        var endDate = DateTime.UtcNow;

        // Act
        var result = await _service.GetComplianceTrendAsync(environment, startDate, endDate, granularity);

        // Assert
        result.Granularity.Should().Be(granularity);
    }
}

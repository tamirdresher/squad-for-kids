using Xunit;
using Moq;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using FedRampDashboard.Api.Controllers;
using FedRampDashboard.Api.Services;
using FedRampDashboard.Api.Models;

namespace FedRampDashboard.Api.Tests.Controllers;

public class ComplianceControllerTests
{
    private readonly Mock<IComplianceService> _mockService;
    private readonly Mock<ILogger<ComplianceController>> _mockLogger;
    private readonly ComplianceController _controller;

    public ComplianceControllerTests()
    {
        _mockService = new Mock<IComplianceService>();
        _mockLogger = new Mock<ILogger<ComplianceController>>();
        _controller = new ComplianceController(_mockService.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task GetComplianceStatus_ReturnsOkResult_WithValidData()
    {
        // Arrange
        var expectedStatus = new ComplianceStatus
        {
            Timestamp = DateTime.UtcNow,
            OverallComplianceRate = 95.5,
            Environments = new()
        };
        _mockService.Setup(s => s.GetComplianceStatusAsync(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(expectedStatus);

        // Act
        var result = await _controller.GetComplianceStatus("ALL", null);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().BeEquivalentTo(expectedStatus);
    }

    [Fact]
    public async Task GetComplianceTrend_ReturnsBadRequest_WhenEnvironmentIsEmpty()
    {
        // Arrange
        var startDate = DateTime.UtcNow.AddDays(-7);
        var endDate = DateTime.UtcNow;

        // Act
        var result = await _controller.GetComplianceTrend(string.Empty, startDate, endDate);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task GetComplianceTrend_ReturnsBadRequest_WhenEndDateBeforeStartDate()
    {
        // Arrange
        var startDate = DateTime.UtcNow;
        var endDate = DateTime.UtcNow.AddDays(-7);

        // Act
        var result = await _controller.GetComplianceTrend("PROD", startDate, endDate);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequest = result as BadRequestObjectResult;
        var error = badRequest!.Value as ApiError;
        error!.ErrorCode.Should().Be("INVALID_DATE_RANGE");
    }

    [Fact]
    public async Task GetComplianceTrend_ReturnsOkResult_WithValidParameters()
    {
        // Arrange
        var environment = "PROD";
        var startDate = DateTime.UtcNow.AddDays(-7);
        var endDate = DateTime.UtcNow;
        var expectedTrend = new ComplianceTrend
        {
            Environment = environment,
            StartDate = startDate,
            EndDate = endDate,
            DataPoints = new()
        };
        _mockService.Setup(s => s.GetComplianceTrendAsync(environment, startDate, endDate, "daily"))
            .ReturnsAsync(expectedTrend);

        // Act
        var result = await _controller.GetComplianceTrend(environment, startDate, endDate);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().BeEquivalentTo(expectedTrend);
    }
}

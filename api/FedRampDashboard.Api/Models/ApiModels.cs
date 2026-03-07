namespace FedRampDashboard.Api.Models;

public class ComplianceStatus
{
    public DateTime Timestamp { get; set; }
    public double OverallComplianceRate { get; set; }
    public List<EnvironmentCompliance> Environments { get; set; } = new();
    public List<ControlCategoryCompliance> ControlCategories { get; set; } = new();
}

public class EnvironmentCompliance
{
    public string Environment { get; set; } = string.Empty;
    public double ComplianceRate { get; set; }
    public int TotalControls { get; set; }
    public int PassingControls { get; set; }
    public int FailingControls { get; set; }
    public List<RecentFailure> RecentFailures { get; set; } = new();
}

public class ControlCategoryCompliance
{
    public string Category { get; set; } = string.Empty;
    public double ComplianceRate { get; set; }
    public int ControlCount { get; set; }
}

public class RecentFailure
{
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public DateTime FailureTime { get; set; }
}

public class ComplianceTrend
{
    public string Environment { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public string Granularity { get; set; } = "daily";
    public List<TrendDataPoint> DataPoints { get; set; } = new();
}

public class TrendDataPoint
{
    public DateTime Timestamp { get; set; }
    public double ComplianceRate { get; set; }
    public int TotalTests { get; set; }
    public int PassedTests { get; set; }
    public int FailedTests { get; set; }
}

public class ValidationResult
{
    public string Id { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public string Environment { get; set; } = string.Empty;
    public string Cluster { get; set; } = string.Empty;
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public string TestCategory { get; set; } = string.Empty;
    public string TestName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int ExecutionTimeMs { get; set; }
    public Dictionary<string, object>? Details { get; set; }
    public ValidationMetadata? Metadata { get; set; }
}

public class ValidationMetadata
{
    public string PipelineId { get; set; } = string.Empty;
    public string PipelineUrl { get; set; } = string.Empty;
    public string CommitSha { get; set; } = string.Empty;
    public string Branch { get; set; } = string.Empty;
}

public class ControlValidationResultList
{
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public int TotalResults { get; set; }
    public List<ValidationResult> Results { get; set; } = new();
    public Pagination Pagination { get; set; } = new();
}

public class EnvironmentSummary
{
    public string Environment { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public string TimeRange { get; set; } = "24h";
    public double ComplianceRate { get; set; }
    public int TotalControls { get; set; }
    public int PassingControls { get; set; }
    public int FailingControls { get; set; }
    public List<ControlBreakdown> ControlBreakdown { get; set; } = new();
    public List<ValidationResult> RecentFailures { get; set; } = new();
}

public class ControlBreakdown
{
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime LastTestTime { get; set; }
}

public class ControlDrift
{
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public string Environment { get; set; } = string.Empty;
    public double CurrentFailureRate { get; set; }
    public double PriorFailureRate { get; set; }
    public double DriftPercentage { get; set; }
    public string Severity { get; set; } = string.Empty;
}

public class ControlDriftList
{
    public DateTime AnalysisTimestamp { get; set; }
    public int CurrentPeriodDays { get; set; }
    public double DriftThreshold { get; set; }
    public List<ControlDrift> DriftingControls { get; set; } = new();
}

public class ComplianceReport
{
    public string ReportId { get; set; } = string.Empty;
    public DateTime GeneratedAt { get; set; }
    public ReportPeriod ReportPeriod { get; set; } = new();
    public List<string> Environments { get; set; } = new();
    public ReportSummary Summary { get; set; } = new();
    public List<ControlResult> ControlResults { get; set; } = new();
}

public class ReportPeriod
{
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
}

public class ReportSummary
{
    public int TotalTests { get; set; }
    public int PassedTests { get; set; }
    public int FailedTests { get; set; }
    public double OverallComplianceRate { get; set; }
}

public class ControlResult
{
    public string ControlId { get; set; } = string.Empty;
    public string ControlName { get; set; } = string.Empty;
    public int PassCount { get; set; }
    public int FailCount { get; set; }
    public double ComplianceRate { get; set; }
}

public class Pagination
{
    public int Total { get; set; }
    public int Limit { get; set; }
    public int Offset { get; set; }
    public bool HasMore { get; set; }
}

public class ApiError
{
    public string ErrorCode { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public string TraceId { get; set; } = string.Empty;
}

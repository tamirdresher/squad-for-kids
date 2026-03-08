namespace FedRampDashboard.Api.Configuration;

public class CacheTelemetryOptions
{
    public const string SectionName = "CacheTelemetry";
    
    public List<string> MonitoredEndpoints { get; set; } = new();
}

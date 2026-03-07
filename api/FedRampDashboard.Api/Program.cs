using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using FedRampDashboard.Api.Services;
using FedRampDashboard.Api.Authorization;
using Azure.Identity;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Azure AD / Entra ID Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

// RBAC Authorization
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Dashboard.Read", policy =>
        policy.RequireRole(
            RbacRoles.SecurityAdmin,
            RbacRoles.SecurityEngineer,
            RbacRoles.SRE,
            RbacRoles.OpsViewer));

    options.AddPolicy("Controls.Read", policy =>
        policy.RequireRole(
            RbacRoles.SecurityAdmin,
            RbacRoles.SecurityEngineer,
            RbacRoles.SRE));

    options.AddPolicy("Analytics.Read", policy =>
        policy.RequireRole(
            RbacRoles.SecurityAdmin,
            RbacRoles.SecurityEngineer,
            RbacRoles.SRE));

    options.AddPolicy("Reports.Export", policy =>
        policy.RequireRole(
            RbacRoles.SecurityAdmin,
            RbacRoles.SecurityEngineer,
            RbacRoles.Auditor));

    options.AddPolicy("Admin.Full", policy =>
        policy.RequireRole(RbacRoles.SecurityAdmin));
});

// Cosmos DB Client
builder.Services.AddSingleton<CosmosClient>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var endpoint = config["CosmosDb:Endpoint"] ?? throw new InvalidOperationException("CosmosDb:Endpoint not configured");
    var credential = new DefaultAzureCredential();
    return new CosmosClient(endpoint, credential);
});

// Services
builder.Services.AddScoped<ICosmosDbService, CosmosDbService>();
builder.Services.AddScoped<ILogAnalyticsService, LogAnalyticsService>();
builder.Services.AddScoped<IComplianceService, ComplianceService>();
builder.Services.AddScoped<IControlsService, ControlsService>();
builder.Services.AddScoped<IEnvironmentsService, EnvironmentsService>();
builder.Services.AddScoped<IHistoryService, HistoryService>();
builder.Services.AddScoped<IReportsService, ReportsService>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new()
    {
        Title = "FedRAMP Security Dashboard API",
        Version = "v1",
        Description = "REST API for FedRAMP compliance monitoring with RBAC"
    });
});

// CORS for local development
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowDashboard", policy =>
    {
        policy.WithOrigins("https://localhost:3000", "https://fedramp-dashboard.azurewebsites.net")
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowDashboard");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

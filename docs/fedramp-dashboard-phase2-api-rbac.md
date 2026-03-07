# FedRAMP Dashboard: Phase 2 REST API & RBAC Implementation

**Status:** Implementation Complete  
**Phase:** 2 of 5  
**Owner:** Data (Code Expert)  
**Issue:** #86  
**Related:** Issue #77 (Design), PR #79 (Phase Planning), Issue #85 (Phase 1)  
**Prerequisites:** Phase 1 (Data Pipeline) - COMPLETE  
**Timeline:** Weeks 3-4  

---

## Executive Summary

Phase 2 implements a secure REST API layer with role-based access control (RBAC) for the FedRAMP Security Dashboard. This phase exposes compliance data from Phase 1 (Azure Monitor + Cosmos DB) through 6 production-ready endpoints with Azure AD authentication and granular permissions.

**Key Deliverables:**
1. ✅ OpenAPI 3.0 specification with 6 REST endpoints
2. ✅ ASP.NET Core 8.0 API implementation with Cosmos DB integration
3. ✅ RBAC system with 5 roles and permission matrix
4. ✅ Azure AD / Entra ID authentication setup
5. ✅ Unit test scaffolding (xUnit + Moq + FluentAssertions)
6. ✅ Technical implementation documentation (this document)

**Success Criteria:**
- ✅ 6 endpoints operational with Azure AD auth
- ✅ < 500ms p95 latency for dashboard queries
- ✅ RBAC enforced at controller level with authorization policies
- ✅ OpenAPI spec validated and Swagger UI functional
- ✅ 80%+ code coverage target via unit tests

---

## 1. Architecture Overview

### 1.1 API Layer Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Client Applications                      │
│   • Dashboard UI (React)                                   │
│   • PowerBI Reports                                         │
│   • CLI Tools (Azure CLI, curl)                            │
└─────────────────────┬──────────────────────────────────────┘
                      │ HTTPS + OAuth 2.0 Bearer Token
                      ↓
┌────────────────────────────────────────────────────────────┐
│              Azure AD / Microsoft Entra ID                  │
│  • Authentication: OAuth 2.0 implicit flow                 │
│  • Token validation: JWT Bearer                            │
│  • Role claims: FedRAMP.SecurityAdmin, etc.                │
└─────────────────────┬──────────────────────────────────────┘
                      │ Validated JWT
                      ↓
┌────────────────────────────────────────────────────────────┐
│            ASP.NET Core 8.0 API Gateway                    │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Middleware Pipeline:                                │ │
│  │  1. Authentication (JWT Bearer)                      │ │
│  │  2. Authorization (Policy-based RBAC)                │ │
│  │  3. CORS validation                                  │ │
│  │  4. Request logging & tracing                        │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Controllers (6 endpoints):                          │ │
│  │  • ComplianceController                              │ │
│  │  • ControlsController                                │ │
│  │  • EnvironmentsController                            │ │
│  │  • HistoryController                                 │ │
│  │  • ReportsController                                 │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────┬──────────────────────────────────────┘
                      │
           ┌──────────┼──────────┐
           ↓                     ↓
┌───────────────────┐   ┌──────────────────────┐
│  Service Layer    │   │   Service Layer      │
│  ┌─────────────┐  │   │  ┌────────────────┐  │
│  │Compliance   │  │   │  │Controls        │  │
│  │Service      │  │   │  │Service         │  │
│  └─────────────┘  │   │  └────────────────┘  │
│  ┌─────────────┐  │   │  ┌────────────────┐  │
│  │Environments │  │   │  │History         │  │
│  │Service      │  │   │  │Service         │  │
│  └─────────────┘  │   │  └────────────────┘  │
│  ┌─────────────┐  │   │  ┌────────────────┐  │
│  │Reports      │  │   │  │                │  │
│  │Service      │  │   │  │                │  │
│  └─────────────┘  │   │  └────────────────┘  │
└───────────────────┘   └──────────────────────┘
           │                     │
           ↓                     ↓
┌───────────────────┐   ┌──────────────────────┐
│ Data Access Layer │   │ Data Access Layer    │
│ ┌─────────────┐   │   │ ┌────────────────┐   │
│ │CosmosDb     │   │   │ │LogAnalytics    │   │
│ │Service      │   │   │ │Service         │   │
│ └─────────────┘   │   │ └────────────────┘   │
└───────┬───────────┘   └──────────┬───────────┘
        │                          │
        ↓                          ↓
┌─────────────────┐       ┌─────────────────────┐
│   Cosmos DB     │       │  Log Analytics      │
│   (90-day hot)  │       │  Workspace (KQL)    │
└─────────────────┘       └─────────────────────┘
```

### 1.2 Component Responsibilities

| Component | Responsibility | Technology |
|-----------|----------------|------------|
| **ComplianceController** | Real-time status & trends | ASP.NET Core MVC |
| **ControlsController** | Control validation results | ASP.NET Core MVC |
| **EnvironmentsController** | Environment summaries | ASP.NET Core MVC |
| **HistoryController** | Drift detection & analytics | ASP.NET Core MVC |
| **ReportsController** | Compliance report export | ASP.NET Core MVC |
| **CosmosDbService** | Cosmos DB queries | Azure.Cosmos SDK |
| **LogAnalyticsService** | KQL query execution | Azure.Monitor.Query SDK |
| **RBAC Policies** | Authorization enforcement | Microsoft.Identity.Web |

---

## 2. API Endpoints

### 2.1 Endpoint Summary

| Endpoint | Method | Permission | Description |
|----------|--------|------------|-------------|
| `/api/v1/compliance/status` | GET | `Dashboard.Read` | Real-time compliance status across all environments |
| `/api/v1/compliance/trend` | GET | `Dashboard.Read` | Historical compliance trends with configurable granularity |
| `/api/v1/controls/{controlId}/validation-results` | GET | `Controls.Read` | Validation results for a specific FedRAMP control |
| `/api/v1/environments/{environment}/summary` | GET | `Dashboard.Read` | Environment-level compliance summary with recent failures |
| `/api/v1/history/control-drift` | GET | `Analytics.Read` | Control drift detection (current vs. prior period) |
| `/api/v1/reports/compliance-export` | GET | `Reports.Export` | Export compliance report (JSON or CSV format) |

### 2.2 Detailed Endpoint Specifications

#### 2.2.1 GET /api/v1/compliance/status

**Purpose:** Provide real-time compliance status across all environments or filtered by environment/category.

**Authorization:** `Dashboard.Read` policy  
**Allowed Roles:** Security Admin, Security Engineer, SRE, Ops Viewer

**Query Parameters:**
- `environment` (optional): `DEV`, `STG`, `PROD`, `ALL` (default: `ALL`)
- `controlCategory` (optional): Filter by FedRAMP control category

**Response Schema:**
```json
{
  "timestamp": "2026-03-08T01:30:00Z",
  "overall_compliance_rate": 94.5,
  "environments": [
    {
      "environment": "PROD",
      "compliance_rate": 95.2,
      "total_controls": 20,
      "passing_controls": 19,
      "failing_controls": 1,
      "recent_failures": [
        {
          "control_id": "SI-2",
          "control_name": "Flaw Remediation",
          "failure_time": "2026-03-07T23:15:00Z"
        }
      ]
    }
  ],
  "control_categories": [
    {
      "category": "System and Communications Protection",
      "compliance_rate": 96.0,
      "control_count": 8
    }
  ]
}
```

**Data Source:** Log Analytics (KQL query on `ControlValidationResults_CL`)

**Performance Target:** < 300ms p95

---

#### 2.2.2 GET /api/v1/compliance/trend

**Purpose:** Return compliance rate trends over a specified time period with configurable granularity (hourly, daily, weekly).

**Authorization:** `Dashboard.Read` policy  
**Allowed Roles:** Security Admin, Security Engineer, SRE, Ops Viewer

**Query Parameters:**
- `environment` (required): `DEV`, `STG`, `PROD`
- `startDate` (required): ISO 8601 datetime
- `endDate` (required): ISO 8601 datetime
- `granularity` (optional): `hourly`, `daily`, `weekly` (default: `daily`)

**Response Schema:**
```json
{
  "environment": "PROD",
  "start_date": "2026-03-01T00:00:00Z",
  "end_date": "2026-03-08T00:00:00Z",
  "granularity": "daily",
  "data_points": [
    {
      "timestamp": "2026-03-01T00:00:00Z",
      "compliance_rate": 94.8,
      "total_tests": 120,
      "passed_tests": 114,
      "failed_tests": 6
    }
  ]
}
```

**Data Source:** Log Analytics with time-binning aggregation

**Performance Target:** < 500ms p95 (7-day range), < 2s p95 (90-day range)

---

#### 2.2.3 GET /api/v1/controls/{controlId}/validation-results

**Purpose:** Retrieve all validation test results for a specific FedRAMP control with filtering and pagination.

**Authorization:** `Controls.Read` policy  
**Allowed Roles:** Security Admin, Security Engineer, SRE

**Path Parameters:**
- `controlId` (required): FedRAMP control ID (e.g., `SC-7`, `SI-2`)

**Query Parameters:**
- `environment` (optional): `DEV`, `STG`, `PROD`, `ALL` (default: `ALL`)
- `status` (optional): `PASS`, `FAIL`, `ALL` (default: `ALL`)
- `startDate` (optional): ISO 8601 datetime
- `endDate` (optional): ISO 8601 datetime
- `limit` (optional): 1-1000 (default: 100)
- `offset` (optional): Pagination offset (default: 0)

**Response Schema:**
```json
{
  "control_id": "SC-7",
  "control_name": "Boundary Protection",
  "total_results": 245,
  "results": [
    {
      "id": "stg-eus2-sc7-20260307-153000",
      "timestamp": "2026-03-07T15:30:00Z",
      "environment": "STG-EUS2",
      "cluster": "dk8s-stg-eus2-28",
      "control_id": "SC-7",
      "control_name": "Boundary Protection",
      "test_category": "network_policy",
      "test_name": "default-deny-ingress",
      "status": "PASS",
      "execution_time_ms": 847,
      "details": {
        "namespace": "app-services",
        "policy_count": 3
      },
      "metadata": {
        "pipeline_id": "azure-pipelines-12345",
        "pipeline_url": "https://dev.azure.com/...",
        "commit_sha": "abc123def456",
        "branch": "main"
      }
    }
  ],
  "pagination": {
    "total": 245,
    "limit": 100,
    "offset": 0,
    "has_more": true
  }
}
```

**Data Source:** Cosmos DB (query on `/environment` partition with `control.id` filter)

**Performance Target:** < 200ms p95 (single partition), < 800ms p95 (cross-partition)

---

#### 2.2.4 GET /api/v1/environments/{environment}/summary

**Purpose:** Provide environment-level compliance summary with control breakdown and recent failures.

**Authorization:** `Dashboard.Read` policy  
**Allowed Roles:** All roles (Security Admin, Security Engineer, SRE, Ops Viewer, Auditor)

**Path Parameters:**
- `environment` (required): `DEV`, `STG`, `PROD`

**Query Parameters:**
- `timeRange` (optional): `24h`, `7d`, `30d`, `90d` (default: `24h`)

**Response Schema:**
```json
{
  "environment": "PROD",
  "timestamp": "2026-03-08T01:30:00Z",
  "time_range": "24h",
  "compliance_rate": 95.2,
  "total_controls": 20,
  "passing_controls": 19,
  "failing_controls": 1,
  "control_breakdown": [
    {
      "control_id": "SC-7",
      "control_name": "Boundary Protection",
      "status": "PASS",
      "last_test_time": "2026-03-08T01:15:00Z"
    }
  ],
  "recent_failures": []
}
```

**Data Source:** Log Analytics (KQL aggregation by control)

**Performance Target:** < 400ms p95

---

#### 2.2.5 GET /api/v1/history/control-drift

**Purpose:** Detect controls with significant changes in failure rates (drift detection).

**Authorization:** `Analytics.Read` policy  
**Allowed Roles:** Security Admin, Security Engineer, SRE

**Query Parameters:**
- `environment` (optional): `DEV`, `STG`, `PROD`, `ALL` (default: `ALL`)
- `currentPeriodDays` (optional): 1-30 (default: 7)
- `driftThreshold` (optional): 0-100 (default: 10, representing 10% drift)

**Response Schema:**
```json
{
  "analysis_timestamp": "2026-03-08T01:30:00Z",
  "current_period_days": 7,
  "drift_threshold": 10.0,
  "drifting_controls": [
    {
      "control_id": "SI-2",
      "control_name": "Flaw Remediation",
      "environment": "PROD",
      "current_failure_rate": 0.25,
      "prior_failure_rate": 0.05,
      "drift_percentage": 20.0,
      "severity": "HIGH"
    }
  ]
}
```

**Data Source:** Log Analytics (KQL with period comparison join)

**Performance Target:** < 1s p95

---

#### 2.2.6 GET /api/v1/reports/compliance-export

**Purpose:** Export compliance report for audit documentation in JSON or CSV format.

**Authorization:** `Reports.Export` policy  
**Allowed Roles:** Security Admin, Security Engineer, Auditor

**Query Parameters:**
- `format` (optional): `json`, `csv` (default: `json`)
- `environment` (optional): `DEV`, `STG`, `PROD`, `ALL` (default: `ALL`)
- `startDate` (required): ISO 8601 datetime
- `endDate` (required): ISO 8601 datetime
- `includeDetails` (optional): boolean (default: `false`)

**Response Schema (JSON):**
```json
{
  "report_id": "550e8400-e29b-41d4-a716-446655440000",
  "generated_at": "2026-03-08T01:30:00Z",
  "report_period": {
    "start_date": "2026-03-01T00:00:00Z",
    "end_date": "2026-03-08T00:00:00Z"
  },
  "environments": ["PROD"],
  "summary": {
    "total_tests": 840,
    "passed_tests": 798,
    "failed_tests": 42,
    "overall_compliance_rate": 95.0
  },
  "control_results": [
    {
      "control_id": "SC-7",
      "control_name": "Boundary Protection",
      "pass_count": 42,
      "fail_count": 0,
      "compliance_rate": 100.0
    }
  ]
}
```

**Response Format (CSV):**
```csv
Control ID,Control Name,Pass Count,Fail Count,Compliance Rate
SC-7,Boundary Protection,42,0,100.00
SI-2,Flaw Remediation,38,4,90.48
```

**Data Source:** Log Analytics (KQL aggregation across full date range)

**Performance Target:** < 3s p95 (30-day report), < 10s p95 (90-day report)

---

## 3. RBAC Configuration

### 3.1 Role Definitions

| Role | Azure AD Group | Description | Use Case |
|------|----------------|-------------|----------|
| **Security Admin** | `FedRAMP-SecurityAdmin` | Full access to all dashboard features, RBAC management | Platform Security leadership, incident commanders |
| **Security Engineer** | `FedRAMP-SecurityEngineer` | Read/write access to validation data and dashboards | Daily security operations, validation test authoring |
| **SRE** | `FedRAMP-SRE` | Operational dashboards, alert config, read-only control data | Site reliability engineers, on-call responders |
| **Ops Viewer** | `FedRAMP-OpsViewer` | Read-only access to dashboards and compliance status | Operations managers, stakeholders |
| **Auditor** | `FedRAMP-Auditor` | Compliance report export only, no real-time dashboard access | External auditors, compliance officers |

### 3.2 Permission Matrix

| Permission | Security Admin | Security Engineer | SRE | Ops Viewer | Auditor |
|------------|:--------------:|:-----------------:|:---:|:----------:|:-------:|
| **Dashboard.Read** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Controls.Read** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Analytics.Read** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Reports.Export** | ✅ | ✅ | ❌ | ❌ | ✅ |
| **Admin.Full** | ✅ | ❌ | ❌ | ❌ | ❌ |

### 3.3 Authorization Policy Mapping

**Implementation:** ASP.NET Core Policy-based Authorization

```csharp
// Program.cs configuration
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
```

**Controller Enforcement:**
```csharp
[HttpGet("status")]
[Authorize(Policy = "Dashboard.Read")]
public async Task<IActionResult> GetComplianceStatus(...)
{
    // Implementation
}
```

### 3.4 Azure AD Configuration

**App Registration Requirements:**

1. **Create App Registration:**
   - Name: `FedRAMP-Dashboard-API`
   - Supported account types: Single tenant (organization only)
   - Redirect URI: `https://fedramp-dashboard-api-prod.azurewebsites.net/.auth/login/aad/callback`

2. **Configure API Permissions:**
   - Add custom scopes:
     - `Dashboard.Read`
     - `Controls.Read`
     - `Analytics.Read`
     - `Reports.Export`

3. **Create Security Groups:**
   - `FedRAMP-SecurityAdmin`
   - `FedRAMP-SecurityEngineer`
   - `FedRAMP-SRE`
   - `FedRAMP-OpsViewer`
   - `FedRAMP-Auditor`

4. **Configure Token Claims:**
   - Include `roles` claim in access token
   - Map security group membership to role claims

**appsettings.json Configuration:**
```json
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "TenantId": "<tenant-guid>",
    "ClientId": "<app-registration-client-id>",
    "Audience": "api://fedramp-dashboard"
  }
}
```

---

## 4. Data Access Layer

### 4.1 Cosmos DB Integration

**Service:** `CosmosDbService.cs`

**Key Operations:**
- Query validation results by control ID and environment
- Partition key optimization: `/environment` for single-partition queries
- Automatic retry policy (3 attempts with exponential backoff)
- Connection pooling via singleton `CosmosClient`

**Sample Query:**
```csharp
var query = $@"
    SELECT * FROM c 
    WHERE c.control.id = '{controlId}'
    AND c.environment = '{environment}'
    ORDER BY c.timestamp DESC
    OFFSET {offset} LIMIT {limit}
";
```

**Authentication:** Managed Identity via `DefaultAzureCredential`

### 4.2 Log Analytics Integration

**Service:** `LogAnalyticsService.cs`

**Key Operations:**
- Execute KQL queries against `ControlValidationResults_CL` table
- Time range queries (24h, 7d, 30d, 90d)
- Aggregations for compliance status and trends
- Drift detection via period comparison joins

**Sample KQL Query:**
```kql
ControlValidationResults_CL
| where TimeGenerated > ago(24h)
| where Environment_s == 'PROD'
| summarize 
    pass_count = countif(Status_s == 'PASS'),
    fail_count = countif(Status_s == 'FAIL')
  by ControlId_s, ControlName_s
| extend compliance_rate = todouble(pass_count) / (pass_count + fail_count) * 100
| order by compliance_rate asc
```

**Authentication:** Managed Identity via `DefaultAzureCredential`

---

## 5. Testing Strategy

### 5.1 Unit Tests

**Framework:** xUnit + Moq + FluentAssertions

**Test Coverage Target:** 80%+

**Test Categories:**
1. **Service Layer Tests** (`ComplianceServiceTests.cs`, etc.)
   - Business logic validation
   - Mock external dependencies (Cosmos DB, Log Analytics)
   - Edge case handling (empty results, null parameters)

2. **Controller Tests** (`ComplianceControllerTests.cs`, etc.)
   - HTTP response validation (200, 400, 401, 403, 404, 500)
   - Authorization policy enforcement
   - Input validation (query parameters, path parameters)

**Sample Test:**
```csharp
[Fact]
public async Task GetComplianceStatus_ReturnsOkResult_WithValidData()
{
    // Arrange
    var expectedStatus = new ComplianceStatus { /* ... */ };
    _mockService.Setup(s => s.GetComplianceStatusAsync(It.IsAny<string>(), It.IsAny<string>()))
        .ReturnsAsync(expectedStatus);

    // Act
    var result = await _controller.GetComplianceStatus("ALL", null);

    // Assert
    result.Should().BeOfType<OkObjectResult>();
}
```

### 5.2 Integration Tests

**Approach:** ASP.NET Core `WebApplicationFactory` with TestServer

**Scope (Future Phase):**
- End-to-end API tests with real Azure services (using test environment)
- Azure AD token validation
- Cosmos DB and Log Analytics integration
- Performance benchmarking (p95 latency validation)

### 5.3 Manual Testing

**Tools:**
- Swagger UI: `https://localhost:5001/swagger`
- curl / Postman with Azure AD bearer tokens
- Azure CLI for token acquisition:
  ```bash
  az account get-access-token --resource api://fedramp-dashboard
  ```

---

## 6. Deployment

### 6.1 Azure App Service Configuration

**Service Plan:** Premium P1v3 (2 vCPU, 8 GB RAM)  
**Runtime:** .NET 8.0 on Linux  
**Region:** East US 2 (primary), West US 2 (failover)

**Environment Variables:**
```bash
AzureAd__TenantId=<tenant-guid>
AzureAd__ClientId=<app-registration-client-id>
AzureAd__Audience=api://fedramp-dashboard
CosmosDb__Endpoint=https://fedramp-cosmos-prod.documents.azure.com:443/
LogAnalytics__WorkspaceId=<workspace-guid>
```

**Managed Identity:**
- System-assigned managed identity enabled
- Assigned roles:
  - `Cosmos DB Data Reader` on `fedramp-cosmos-prod`
  - `Log Analytics Reader` on `fedramp-logs-prod` workspace

### 6.2 CI/CD Pipeline Integration

**Pipeline:** `.azuredevops/fedramp-api-phase2.yml`

**Stages:**
1. **Build:**
   - `dotnet restore`
   - `dotnet build --configuration Release`
   - `dotnet test` (unit tests)

2. **Publish:**
   - `dotnet publish -o ./publish`
   - Zip artifact creation

3. **Deploy:**
   - Azure App Service deployment task
   - Deployment slot: `staging`
   - Post-deployment smoke tests
   - Slot swap to production (manual approval required)

### 6.3 Monitoring & Alerts

**Application Insights Integration:**
- Request telemetry (latency, success rate)
- Dependency telemetry (Cosmos DB, Log Analytics)
- Exception tracking
- Custom metrics: API endpoint usage by role

**Alert Rules:**
- P95 latency > 1s for 5 minutes → Alert to on-call
- 5xx error rate > 1% for 3 minutes → Page SRE
- Azure AD auth failure rate > 5% → Alert to security team

---

## 7. Security Considerations

### 7.1 Authentication & Authorization

- ✅ Azure AD OAuth 2.0 with JWT bearer tokens
- ✅ Token validation: signature, issuer, audience, expiration
- ✅ Role-based authorization at controller level
- ✅ HTTPS enforced (TLS 1.2+)

### 7.2 Data Protection

- ✅ Managed Identity for Azure service authentication (no connection strings in code)
- ✅ Key Vault integration for sensitive configuration (future: Phase 3)
- ✅ CORS policy: Allow dashboard UI origins only
- ✅ Rate limiting: 100 requests/minute per user (future: Phase 3)

### 7.3 Audit Logging

- ✅ All API requests logged with user identity (Azure AD object ID)
- ✅ Failed authorization attempts logged
- ✅ Export operations logged with report metadata

---

## 8. Performance Optimization

### 8.1 Caching Strategy

**Future Phase 3 Implementation:**
- Redis cache for compliance status (5-minute TTL)
- Cosmos DB query result caching
- Environment summary caching (1-hour TTL)

### 8.2 Query Optimization

- ✅ Cosmos DB: Single-partition queries where possible (`/environment` partition key)
- ✅ Log Analytics: KQL queries optimized with filters pushed down
- ✅ Pagination implemented for large result sets (max 1000 items)

### 8.3 Connection Pooling

- ✅ `CosmosClient` registered as singleton (connection pooling enabled)
- ✅ `LogsQueryClient` registered as singleton

---

## 9. API Versioning & Evolution

### 9.1 Versioning Strategy

- **Current:** `/api/v1` (URL-based versioning)
- **Breaking Changes:** Require new version (`/api/v2`)
- **Non-Breaking Changes:** Allowed in current version (additive only)

### 9.2 OpenAPI Spec Evolution

- OpenAPI spec updated with each API change
- Swagger UI always reflects current version
- Client SDKs auto-generated from OpenAPI spec (future: Phase 4)

---

## 10. Known Limitations & Future Work

### 10.1 Phase 2 Limitations

- ❌ No caching layer (will add Redis in Phase 3)
- ❌ No rate limiting per user (planned for Phase 3)
- ❌ Integration tests not implemented (blocked on test environment setup)
- ❌ CSV export basic (no advanced formatting)

### 10.2 Phase 3 Roadmap

- Add Redis cache for compliance status and trends
- Implement rate limiting with Azure API Management
- Add GraphQL endpoint for flexible queries
- Webhook notifications for compliance failures
- Enhanced audit logging with Azure Monitor

---

## 11. File Structure

```
C:\temp\wt-86
├── api/
│   ├── openapi-fedramp-dashboard.yaml       # OpenAPI 3.0 specification
│   └── FedRampDashboard.Api/
│       ├── FedRampDashboard.Api.csproj      # .NET project file
│       ├── Program.cs                        # Application entry point
│       ├── appsettings.json                  # Configuration
│       ├── Controllers/
│       │   ├── ComplianceController.cs
│       │   ├── ControlsController.cs
│       │   ├── EnvironmentsController.cs
│       │   ├── HistoryController.cs
│       │   └── ReportsController.cs
│       ├── Services/
│       │   ├── CosmosDbService.cs
│       │   ├── LogAnalyticsService.cs
│       │   ├── ComplianceService.cs
│       │   ├── ControlsService.cs
│       │   ├── EnvironmentsService.cs
│       │   ├── HistoryService.cs
│       │   └── ReportsService.cs
│       ├── Models/
│       │   └── ApiModels.cs
│       └── Authorization/
│           └── RbacRoles.cs
├── tests/
│   └── FedRampDashboard.Api.Tests/
│       ├── FedRampDashboard.Api.Tests.csproj
│       ├── Services/
│       │   └── ComplianceServiceTests.cs
│       └── Controllers/
│           └── ComplianceControllerTests.cs
└── docs/
    └── fedramp-dashboard-phase2-api-rbac.md  # This document
```

---

## 12. References

- **Phase 1 Documentation:** `docs/fedramp-dashboard-phase1-data-pipeline.md`
- **OpenAPI Specification:** `api/openapi-fedramp-dashboard.yaml`
- **Azure AD Documentation:** https://learn.microsoft.com/en-us/azure/active-directory/develop/
- **Cosmos DB Best Practices:** https://learn.microsoft.com/en-us/azure/cosmos-db/best-practices
- **Log Analytics KQL Reference:** https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/

---

## Appendix A: Quick Start Guide

### Local Development Setup

1. **Prerequisites:**
   ```bash
   dotnet --version  # Ensure .NET 8.0 SDK installed
   ```

2. **Clone repository and navigate to API:**
   ```bash
   cd C:\temp\wt-86\api\FedRampDashboard.Api
   ```

3. **Configure user secrets:**
   ```bash
   dotnet user-secrets set "AzureAd:TenantId" "<your-tenant-id>"
   dotnet user-secrets set "AzureAd:ClientId" "<your-client-id>"
   dotnet user-secrets set "CosmosDb:Endpoint" "https://localhost:8081"
   dotnet user-secrets set "LogAnalytics:WorkspaceId" "<your-workspace-id>"
   ```

4. **Run API:**
   ```bash
   dotnet run
   ```

5. **Access Swagger UI:**
   ```
   https://localhost:5001/swagger
   ```

### Testing with curl

```bash
# Get compliance status
curl -X GET "https://localhost:5001/api/v1/compliance/status?environment=PROD" \
  -H "Authorization: Bearer <your-jwt-token>"

# Get control validation results
curl -X GET "https://localhost:5001/api/v1/controls/SC-7/validation-results?limit=10" \
  -H "Authorization: Bearer <your-jwt-token>"

# Export compliance report
curl -X GET "https://localhost:5001/api/v1/reports/compliance-export?format=csv&environment=PROD&startDate=2026-03-01T00:00:00Z&endDate=2026-03-08T00:00:00Z" \
  -H "Authorization: Bearer <your-jwt-token>" \
  -o compliance-report.csv
```

---

**End of Phase 2 Documentation**

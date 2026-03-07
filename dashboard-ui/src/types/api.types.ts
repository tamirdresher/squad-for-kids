export type Environment = 'DEV' | 'STG' | 'PROD' | 'ALL';

export type TestStatus = 'PASS' | 'FAIL';

export type Granularity = 'hourly' | 'daily' | 'weekly';

export type TimeRange = '24h' | '7d' | '30d' | '90d';

export type DriftSeverity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export type ExportFormat = 'json' | 'csv';

export interface ComplianceStatus {
  timestamp: string;
  overall_compliance_rate: number;
  environments: EnvironmentStatus[];
  control_categories: ControlCategory[];
}

export interface EnvironmentStatus {
  environment: Environment;
  compliance_rate: number;
  total_controls: number;
  passing_controls: number;
  failing_controls: number;
  recent_failures: RecentFailure[];
}

export interface RecentFailure {
  control_id: string;
  control_name: string;
  failure_time: string;
}

export interface ControlCategory {
  category: string;
  compliance_rate: number;
  control_count: number;
}

export interface ComplianceTrend {
  environment: string;
  start_date: string;
  end_date: string;
  granularity: Granularity;
  data_points: TrendDataPoint[];
}

export interface TrendDataPoint {
  timestamp: string;
  compliance_rate: number;
  total_tests: number;
  passed_tests: number;
  failed_tests: number;
}

export interface ValidationResult {
  id: string;
  timestamp: string;
  environment: string;
  cluster: string;
  control_id: string;
  control_name: string;
  test_category: string;
  test_name: string;
  status: TestStatus;
  execution_time_ms: number;
  details: Record<string, unknown>;
  metadata: {
    pipeline_id: string;
    pipeline_url: string;
    commit_sha: string;
    branch: string;
  };
}

export interface ControlValidationResultList {
  control_id: string;
  control_name: string;
  total_results: number;
  results: ValidationResult[];
  pagination: Pagination;
}

export interface Pagination {
  page: number;
  page_size: number;
  total_pages: number;
  total_items: number;
}

export interface EnvironmentSummary {
  environment: string;
  timestamp: string;
  time_range: string;
  compliance_rate: number;
  total_controls: number;
  passing_controls: number;
  failing_controls: number;
  control_breakdown: ControlBreakdown[];
  recent_failures: ValidationResult[];
}

export interface ControlBreakdown {
  control_id: string;
  control_name: string;
  status: 'PASS' | 'FAIL' | 'UNKNOWN';
  last_test_time: string;
}

export interface ControlDrift {
  control_id: string;
  control_name: string;
  environment: string;
  current_failure_rate: number;
  prior_failure_rate: number;
  drift_percentage: number;
  severity: DriftSeverity;
}

export interface ControlDriftList {
  analysis_timestamp: string;
  current_period_days: number;
  drift_threshold: number;
  drifting_controls: ControlDrift[];
}

export interface ComplianceReport {
  report_id: string;
  generated_at: string;
  report_period: {
    start_date: string;
    end_date: string;
  };
  environments: string[];
  summary: {
    total_tests: number;
    passed_tests: number;
    failed_tests: number;
    overall_compliance_rate: number;
  };
  control_results: ControlResult[];
}

export interface ControlResult {
  control_id: string;
  control_name: string;
  pass_count: number;
  fail_count: number;
  compliance_rate: number;
}

export type UserRole = 
  | 'Security Admin' 
  | 'Security Engineer' 
  | 'SRE' 
  | 'Ops Viewer' 
  | 'Auditor';

export interface UserPermissions {
  canViewDashboard: boolean;
  canViewControls: boolean;
  canViewAnalytics: boolean;
  canExportReports: boolean;
  role: UserRole;
}

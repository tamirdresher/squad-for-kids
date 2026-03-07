import axios, { AxiosInstance } from 'axios';
import axiosRetry from 'axios-retry';
import type {
  ComplianceStatus,
  ComplianceTrend,
  ControlValidationResultList,
  EnvironmentSummary,
  ControlDriftList,
  ComplianceReport,
  Environment,
  Granularity,
  TimeRange,
  ExportFormat,
} from '../types/api.types';

class FedRAMPApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string = '/api/v1') {
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    axiosRetry(this.client, {
      retries: 3,
      retryDelay: axiosRetry.exponentialDelay,
      retryCondition: (error) => {
        return axiosRetry.isNetworkOrIdempotentRequestError(error) || error.response?.status === 429;
      },
    });

    this.client.interceptors.request.use((config) => {
      // SECURITY WARNING: localStorage is vulnerable to XSS attacks
      // TODO: Migrate to httpOnly cookies for enhanced security
      const token = localStorage.getItem('azure_ad_token');
      if (token) {
        const sanitizedToken = token.replace(/[^\w\-\.]/g, '');
        config.headers.Authorization = `Bearer ${sanitizedToken}`;
      }
      return config;
    });
  }

  async getComplianceStatus(
    environment: Environment = 'ALL',
    controlCategory?: string
  ): Promise<ComplianceStatus> {
    const params = new URLSearchParams();
    if (environment !== 'ALL') params.append('environment', environment);
    if (controlCategory) params.append('controlCategory', controlCategory);

    const response = await this.client.get<ComplianceStatus>(
      `/compliance/status?${params.toString()}`
    );
    return response.data;
  }

  async getComplianceTrend(
    environment: Exclude<Environment, 'ALL'>,
    startDate: string,
    endDate: string,
    granularity: Granularity = 'daily'
  ): Promise<ComplianceTrend> {
    const params = new URLSearchParams({
      environment,
      startDate,
      endDate,
      granularity,
    });

    const response = await this.client.get<ComplianceTrend>(
      `/compliance/trend?${params.toString()}`
    );
    return response.data;
  }

  async getControlValidationResults(
    controlId: string,
    environment: Environment = 'ALL',
    status: 'PASS' | 'FAIL' | 'ALL' = 'ALL',
    startDate?: string,
    endDate?: string,
    limit: number = 100
  ): Promise<ControlValidationResultList> {
    const params = new URLSearchParams({ limit: limit.toString() });
    if (environment !== 'ALL') params.append('environment', environment);
    if (status !== 'ALL') params.append('status', status);
    if (startDate) params.append('startDate', startDate);
    if (endDate) params.append('endDate', endDate);

    const response = await this.client.get<ControlValidationResultList>(
      `/controls/${controlId}/validation-results?${params.toString()}`
    );
    return response.data;
  }

  async getEnvironmentSummary(
    environment: Exclude<Environment, 'ALL'>,
    timeRange: TimeRange = '24h'
  ): Promise<EnvironmentSummary> {
    const response = await this.client.get<EnvironmentSummary>(
      `/environments/${environment}/summary?timeRange=${timeRange}`
    );
    return response.data;
  }

  async getControlDrift(
    environment: Environment = 'ALL',
    currentPeriodDays: number = 7,
    driftThreshold: number = 10
  ): Promise<ControlDriftList> {
    const params = new URLSearchParams({
      currentPeriodDays: currentPeriodDays.toString(),
      driftThreshold: driftThreshold.toString(),
    });
    if (environment !== 'ALL') params.append('environment', environment);

    const response = await this.client.get<ControlDriftList>(
      `/history/control-drift?${params.toString()}`
    );
    return response.data;
  }

  async exportComplianceReport(
    startDate: string,
    endDate: string,
    format: ExportFormat = 'json',
    environment: Environment = 'ALL',
    includeDetails: boolean = false
  ): Promise<ComplianceReport | Blob> {
    const params = new URLSearchParams({
      format,
      startDate,
      endDate,
      includeDetails: includeDetails.toString(),
    });
    if (environment !== 'ALL') params.append('environment', environment);

    if (format === 'csv') {
      const response = await this.client.get<Blob>(
        `/reports/compliance-export?${params.toString()}`,
        { responseType: 'blob' }
      );
      return response.data;
    }

    const response = await this.client.get<ComplianceReport>(
      `/reports/compliance-export?${params.toString()}`
    );
    return response.data;
  }
}

export const apiClient = new FedRAMPApiClient();

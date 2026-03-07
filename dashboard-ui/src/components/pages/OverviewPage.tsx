import React, { useEffect, useState } from 'react';
import {
  Box,
  Grid,
  Typography,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  SelectChangeEvent,
} from '@mui/material';
import { apiClient } from '../../services/api.service';
import type { ComplianceStatus, Environment } from '../../types/api.types';
import { StatsCard } from '../common/StatsCard';
import { ComplianceDonutChart } from '../charts/ComplianceDonutChart';
import { ControlCategoryChart } from '../charts/ControlCategoryChart';
import { RecentFailuresTable } from '../common/RecentFailuresTable';
import { LoadingSpinner } from '../common/LoadingSpinner';
import { ErrorDisplay } from '../common/ErrorDisplay';

export const OverviewPage: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [data, setData] = useState<ComplianceStatus | null>(null);
  const [environment, setEnvironment] = useState<Environment>('ALL');

  useEffect(() => {
    fetchComplianceStatus();
  }, [environment]);

  const fetchComplianceStatus = async () => {
    try {
      setLoading(true);
      setError(null);
      const status = await apiClient.getComplianceStatus(environment);
      setData(status);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  const handleEnvironmentChange = (event: SelectChangeEvent) => {
    setEnvironment(event.target.value as Environment);
  };

  if (loading) return <LoadingSpinner message="Loading compliance overview..." />;
  if (error) return <ErrorDisplay error={error} />;
  if (!data) return <ErrorDisplay error="No data available" />;

  const totalControls = data.environments.reduce((sum, env) => sum + env.total_controls, 0);
  const passingControls = data.environments.reduce((sum, env) => sum + env.passing_controls, 0);
  const failingControls = data.environments.reduce((sum, env) => sum + env.failing_controls, 0);
  const allFailures = data.environments.flatMap(env => env.recent_failures);

  return (
    <Box>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4" component="h1">
          FedRAMP Compliance Overview
        </Typography>
        <FormControl sx={{ minWidth: 200 }}>
          <InputLabel>Environment</InputLabel>
          <Select value={environment} onChange={handleEnvironmentChange} label="Environment">
            <MenuItem value="ALL">All Environments</MenuItem>
            <MenuItem value="DEV">DEV</MenuItem>
            <MenuItem value="STG">STG</MenuItem>
            <MenuItem value="PROD">PROD</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Overall Compliance"
            value={`${data.overall_compliance_rate.toFixed(1)}%`}
            color={data.overall_compliance_rate >= 95 ? 'success' : 'warning'}
            progress={data.overall_compliance_rate}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Total Controls"
            value={totalControls}
            subtitle={`Across ${data.environments.length} environment(s)`}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Passing Controls"
            value={passingControls}
            color="success"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Failing Controls"
            value={failingControls}
            color={failingControls > 0 ? 'error' : 'success'}
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <ComplianceDonutChart
            passing={passingControls}
            failing={failingControls}
            title="Overall Control Status"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <ControlCategoryChart categories={data.control_categories} />
        </Grid>

        {data.environments.map((env) => (
          <Grid item xs={12} md={4} key={env.environment}>
            <ComplianceDonutChart
              passing={env.passing_controls}
              failing={env.failing_controls}
              title={`${env.environment} Environment`}
            />
          </Grid>
        ))}

        {allFailures.length > 0 && (
          <Grid item xs={12}>
            <RecentFailuresTable failures={allFailures} />
          </Grid>
        )}
      </Grid>
    </Box>
  );
};

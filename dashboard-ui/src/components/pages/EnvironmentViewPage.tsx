import React, { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  SelectChangeEvent,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
} from '@mui/material';
import { format } from 'date-fns';
import { apiClient } from '../../services/api.service';
import type { EnvironmentSummary, TimeRange } from '../../types/api.types';
import { LoadingSpinner } from '../common/LoadingSpinner';
import { ErrorDisplay } from '../common/ErrorDisplay';
import { StatsCard } from '../common/StatsCard';
import { ComplianceDonutChart } from '../charts/ComplianceDonutChart';

type EnvironmentType = 'DEV' | 'STG' | 'PROD';

export const EnvironmentViewPage: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [data, setData] = useState<EnvironmentSummary | null>(null);
  const [environment, setEnvironment] = useState<EnvironmentType>('PROD');
  const [timeRange, setTimeRange] = useState<TimeRange>('24h');

  useEffect(() => {
    fetchEnvironmentSummary();
  }, [environment, timeRange]);

  const fetchEnvironmentSummary = async () => {
    try {
      setLoading(true);
      setError(null);
      const summary = await apiClient.getEnvironmentSummary(environment, timeRange);
      setData(summary);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  const handleEnvironmentChange = (event: SelectChangeEvent) => {
    setEnvironment(event.target.value as EnvironmentType);
  };

  const handleTimeRangeChange = (event: SelectChangeEvent) => {
    setTimeRange(event.target.value as TimeRange);
  };

  const getStatusColor = (status: string): 'success' | 'error' | 'default' => {
    if (status === 'PASS') return 'success';
    if (status === 'FAIL') return 'error';
    return 'default';
  };

  if (loading) return <LoadingSpinner message="Loading environment summary..." />;
  if (error) return <ErrorDisplay error={error} />;
  if (!data) return <ErrorDisplay error="No data available" />;

  return (
    <Box>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4" component="h1">
          Environment View
        </Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <FormControl sx={{ minWidth: 150 }}>
            <InputLabel>Environment</InputLabel>
            <Select value={environment} onChange={handleEnvironmentChange} label="Environment">
              <MenuItem value="DEV">DEV</MenuItem>
              <MenuItem value="STG">STG</MenuItem>
              <MenuItem value="PROD">PROD</MenuItem>
            </Select>
          </FormControl>
          <FormControl sx={{ minWidth: 150 }}>
            <InputLabel>Time Range</InputLabel>
            <Select value={timeRange} onChange={handleTimeRangeChange} label="Time Range">
              <MenuItem value="24h">Last 24 Hours</MenuItem>
              <MenuItem value="7d">Last 7 Days</MenuItem>
              <MenuItem value="30d">Last 30 Days</MenuItem>
              <MenuItem value="90d">Last 90 Days</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </Box>

      <Grid container spacing={3}>
        <Grid item xs={12} md={3}>
          <StatsCard
            title="Compliance Rate"
            value={`${data.compliance_rate.toFixed(1)}%`}
            color={data.compliance_rate >= 95 ? 'success' : 'warning'}
            progress={data.compliance_rate}
          />
        </Grid>
        <Grid item xs={12} md={3}>
          <StatsCard
            title="Total Controls"
            value={data.total_controls}
            subtitle={data.environment}
          />
        </Grid>
        <Grid item xs={12} md={3}>
          <StatsCard
            title="Passing Controls"
            value={data.passing_controls}
            color="success"
          />
        </Grid>
        <Grid item xs={12} md={3}>
          <StatsCard
            title="Failing Controls"
            value={data.failing_controls}
            color={data.failing_controls > 0 ? 'error' : 'success'}
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <ComplianceDonutChart
            passing={data.passing_controls}
            failing={data.failing_controls}
            title={`${data.environment} Control Status`}
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Summary Information
            </Typography>
            <Box sx={{ mt: 2 }}>
              <Typography variant="body2" color="textSecondary" gutterBottom>
                Last Updated
              </Typography>
              <Typography variant="body1" gutterBottom>
                {format(new Date(data.timestamp), 'MMM dd, yyyy HH:mm:ss')}
              </Typography>
              <Typography variant="body2" color="textSecondary" gutterBottom sx={{ mt: 2 }}>
                Time Range
              </Typography>
              <Typography variant="body1">
                {data.time_range}
              </Typography>
            </Box>
          </Paper>
        </Grid>

        <Grid item xs={12}>
          <Paper>
            <Box sx={{ p: 2 }}>
              <Typography variant="h6" gutterBottom>
                Control Breakdown
              </Typography>
            </Box>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Control ID</TableCell>
                    <TableCell>Control Name</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Last Test Time</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.control_breakdown.map((control) => (
                    <TableRow key={control.control_id}>
                      <TableCell>
                        <Chip label={control.control_id} size="small" />
                      </TableCell>
                      <TableCell>{control.control_name}</TableCell>
                      <TableCell>
                        <Chip
                          label={control.status}
                          color={getStatusColor(control.status)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        {format(new Date(control.last_test_time), 'MMM dd, yyyy HH:mm')}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </Grid>

        {data.recent_failures.length > 0 && (
          <Grid item xs={12}>
            <Paper>
              <Box sx={{ p: 2 }}>
                <Typography variant="h6" gutterBottom>
                  Recent Failures
                </Typography>
              </Box>
              <TableContainer>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell>Timestamp</TableCell>
                      <TableCell>Control</TableCell>
                      <TableCell>Test</TableCell>
                      <TableCell>Cluster</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {data.recent_failures.map((failure) => (
                      <TableRow key={failure.id}>
                        <TableCell>
                          {format(new Date(failure.timestamp), 'MMM dd, yyyy HH:mm')}
                        </TableCell>
                        <TableCell>
                          <Chip label={failure.control_id} size="small" />
                        </TableCell>
                        <TableCell>{failure.test_name}</TableCell>
                        <TableCell>{failure.cluster}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </Paper>
          </Grid>
        )}
      </Grid>
    </Box>
  );
};

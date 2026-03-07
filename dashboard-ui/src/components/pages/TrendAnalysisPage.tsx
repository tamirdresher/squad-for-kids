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
  Button,
} from '@mui/material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import { subDays, format as formatDate } from 'date-fns';
import { apiClient } from '../../services/api.service';
import type { ComplianceTrend, ControlDriftList, Granularity, DriftSeverity } from '../../types/api.types';
import { LoadingSpinner } from '../common/LoadingSpinner';
import { ErrorDisplay } from '../common/ErrorDisplay';
import { ComplianceTrendChart } from '../charts/ComplianceTrendChart';

type EnvironmentType = 'DEV' | 'STG' | 'PROD';

export const TrendAnalysisPage: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [trendData, setTrendData] = useState<ComplianceTrend | null>(null);
  const [driftData, setDriftData] = useState<ControlDriftList | null>(null);
  
  const [environment, setEnvironment] = useState<EnvironmentType>('PROD');
  const [granularity, setGranularity] = useState<Granularity>('daily');
  const [startDate, setStartDate] = useState<Date>(subDays(new Date(), 30));
  const [endDate, setEndDate] = useState<Date>(new Date());
  const [driftThreshold, setDriftThreshold] = useState<number>(10);

  useEffect(() => {
    fetchTrendData();
    fetchDriftData();
  }, []);

  const fetchTrendData = async () => {
    try {
      setLoading(true);
      setError(null);
      const trend = await apiClient.getComplianceTrend(
        environment,
        startDate.toISOString(),
        endDate.toISOString(),
        granularity
      );
      setTrendData(trend);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  const fetchDriftData = async () => {
    try {
      const drift = await apiClient.getControlDrift('ALL', 7, driftThreshold);
      setDriftData(drift);
    } catch (err) {
      console.error('Error fetching drift data:', err);
    }
  };

  const handleEnvironmentChange = (event: SelectChangeEvent) => {
    setEnvironment(event.target.value as EnvironmentType);
  };

  const handleGranularityChange = (event: SelectChangeEvent) => {
    setGranularity(event.target.value as Granularity);
  };

  const handleSearch = () => {
    fetchTrendData();
    fetchDriftData();
  };

  const getSeverityColor = (severity: DriftSeverity): 'error' | 'warning' | 'info' | 'default' => {
    switch (severity) {
      case 'CRITICAL': return 'error';
      case 'HIGH': return 'error';
      case 'MEDIUM': return 'warning';
      case 'LOW': return 'info';
      default: return 'default';
    }
  };

  return (
    <Box>
      <Typography variant="h4" component="h1" sx={{ mb: 4 }}>
        Trend Analysis
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Compliance Trend Configuration
        </Typography>
        <LocalizationProvider dateAdapter={AdapterDateFns}>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={3}>
              <FormControl fullWidth>
                <InputLabel>Environment</InputLabel>
                <Select value={environment} onChange={handleEnvironmentChange} label="Environment">
                  <MenuItem value="DEV">DEV</MenuItem>
                  <MenuItem value="STG">STG</MenuItem>
                  <MenuItem value="PROD">PROD</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2}>
              <FormControl fullWidth>
                <InputLabel>Granularity</InputLabel>
                <Select value={granularity} onChange={handleGranularityChange} label="Granularity">
                  <MenuItem value="hourly">Hourly</MenuItem>
                  <MenuItem value="daily">Daily</MenuItem>
                  <MenuItem value="weekly">Weekly</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={3}>
              <DatePicker
                label="Start Date"
                value={startDate}
                onChange={(date) => date && setStartDate(date)}
                slotProps={{ textField: { fullWidth: true } }}
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <DatePicker
                label="End Date"
                value={endDate}
                onChange={(date) => date && setEndDate(date)}
                slotProps={{ textField: { fullWidth: true } }}
              />
            </Grid>
            <Grid item xs={12} md={1}>
              <Button fullWidth variant="contained" onClick={handleSearch}>
                Refresh
              </Button>
            </Grid>
          </Grid>
        </LocalizationProvider>
      </Paper>

      {loading && <LoadingSpinner message="Loading trend analysis..." />}
      
      {error && <ErrorDisplay error={error} />}

      {trendData && !loading && (
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <ComplianceTrendChart 
              data={trendData.data_points}
              title={`Compliance Trend: ${environment} (${granularity})`}
            />
          </Grid>

          <Grid item xs={12}>
            <Paper sx={{ p: 3 }}>
              <Typography variant="h6" gutterBottom>
                Trend Statistics
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6} md={3}>
                  <Typography variant="body2" color="textSecondary">
                    Environment
                  </Typography>
                  <Typography variant="h6">{trendData.environment}</Typography>
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <Typography variant="body2" color="textSecondary">
                    Granularity
                  </Typography>
                  <Typography variant="h6">{trendData.granularity}</Typography>
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <Typography variant="body2" color="textSecondary">
                    Data Points
                  </Typography>
                  <Typography variant="h6">{trendData.data_points.length}</Typography>
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <Typography variant="body2" color="textSecondary">
                    Avg Compliance
                  </Typography>
                  <Typography variant="h6">
                    {(
                      trendData.data_points.reduce((sum, p) => sum + p.compliance_rate, 0) /
                      trendData.data_points.length
                    ).toFixed(1)}%
                  </Typography>
                </Grid>
              </Grid>
            </Paper>
          </Grid>
        </Grid>
      )}

      {driftData && driftData.drifting_controls.length > 0 && (
        <Box sx={{ mt: 4 }}>
          <Typography variant="h5" gutterBottom>
            Control Drift Detection
          </Typography>
          <Typography variant="body2" color="textSecondary" gutterBottom>
            Controls with failure rate changes exceeding {driftThreshold}%
          </Typography>
          
          <Paper sx={{ mt: 2 }}>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Control ID</TableCell>
                    <TableCell>Control Name</TableCell>
                    <TableCell>Environment</TableCell>
                    <TableCell>Current Failure Rate</TableCell>
                    <TableCell>Prior Failure Rate</TableCell>
                    <TableCell>Drift</TableCell>
                    <TableCell>Severity</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {driftData.drifting_controls.map((control, index) => (
                    <TableRow key={`${control.control_id}-${index}`}>
                      <TableCell>
                        <Chip label={control.control_id} size="small" />
                      </TableCell>
                      <TableCell>{control.control_name}</TableCell>
                      <TableCell>{control.environment}</TableCell>
                      <TableCell>{control.current_failure_rate.toFixed(1)}%</TableCell>
                      <TableCell>{control.prior_failure_rate.toFixed(1)}%</TableCell>
                      <TableCell>
                        <Chip 
                          label={`+${control.drift_percentage.toFixed(1)}%`}
                          color="error"
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={control.severity}
                          color={getSeverityColor(control.severity)}
                          size="small"
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </Box>
      )}
    </Box>
  );
};

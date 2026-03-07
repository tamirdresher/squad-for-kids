import React, { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  TextField,
  Grid,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  SelectChangeEvent,
  Button,
} from '@mui/material';
import { format } from 'date-fns';
import { apiClient } from '../../services/api.service';
import type { ControlValidationResultList, Environment, TestStatus } from '../../types/api.types';
import { LoadingSpinner } from '../common/LoadingSpinner';
import { ErrorDisplay } from '../common/ErrorDisplay';
import { StatsCard } from '../common/StatsCard';

export const ControlDetailPage: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [data, setData] = useState<ControlValidationResultList | null>(null);
  const [controlId, setControlId] = useState('SC-7');
  const [environment, setEnvironment] = useState<Environment>('ALL');
  const [status, setStatus] = useState<'PASS' | 'FAIL' | 'ALL'>('ALL');

  const fetchControlData = async () => {
    if (!controlId.trim()) return;

    try {
      setLoading(true);
      setError(null);
      const results = await apiClient.getControlValidationResults(
        controlId,
        environment,
        status
      );
      setData(results);
    } catch (err) {
      setError(err as Error);
      setData(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchControlData();
  }, [controlId, environment, status]);

  const handleEnvironmentChange = (event: SelectChangeEvent) => {
    setEnvironment(event.target.value as Environment);
  };

  const handleStatusChange = (event: SelectChangeEvent) => {
    setStatus(event.target.value as 'PASS' | 'FAIL' | 'ALL');
  };

  const getStatusColor = (status: TestStatus): 'success' | 'error' => {
    return status === 'PASS' ? 'success' : 'error';
  };

  const passCount = data?.results.filter(r => r.status === 'PASS').length || 0;
  const failCount = data?.results.filter(r => r.status === 'FAIL').length || 0;
  const passRate = data?.results.length 
    ? ((passCount / data.results.length) * 100).toFixed(1) 
    : '0.0';

  return (
    <Box>
      <Typography variant="h4" component="h1" sx={{ mb: 4 }}>
        Control Detail View
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={4}>
            <TextField
              fullWidth
              label="Control ID"
              value={controlId}
              onChange={(e) => setControlId(e.target.value)}
              placeholder="e.g., SC-7, SI-2"
            />
          </Grid>
          <Grid item xs={12} md={3}>
            <FormControl fullWidth>
              <InputLabel>Environment</InputLabel>
              <Select value={environment} onChange={handleEnvironmentChange} label="Environment">
                <MenuItem value="ALL">All</MenuItem>
                <MenuItem value="DEV">DEV</MenuItem>
                <MenuItem value="STG">STG</MenuItem>
                <MenuItem value="PROD">PROD</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={3}>
            <FormControl fullWidth>
              <InputLabel>Status</InputLabel>
              <Select value={status} onChange={handleStatusChange} label="Status">
                <MenuItem value="ALL">All</MenuItem>
                <MenuItem value="PASS">Pass</MenuItem>
                <MenuItem value="FAIL">Fail</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={2}>
            <Button 
              fullWidth 
              variant="contained" 
              onClick={fetchControlData}
              disabled={!controlId.trim()}
            >
              Search
            </Button>
          </Grid>
        </Grid>
      </Paper>

      {loading && <LoadingSpinner message="Loading control validation results..." />}
      
      {error && <ErrorDisplay error={error} />}

      {data && !loading && (
        <>
          <Grid container spacing={3} sx={{ mb: 3 }}>
            <Grid item xs={12} md={3}>
              <StatsCard
                title="Control"
                value={data.control_id}
                subtitle={data.control_name}
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <StatsCard
                title="Pass Rate"
                value={`${passRate}%`}
                color={parseFloat(passRate) >= 95 ? 'success' : 'error'}
                progress={parseFloat(passRate)}
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <StatsCard
                title="Passed Tests"
                value={passCount}
                color="success"
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <StatsCard
                title="Failed Tests"
                value={failCount}
                color={failCount > 0 ? 'error' : 'success'}
              />
            </Grid>
          </Grid>

          <Paper>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Timestamp</TableCell>
                    <TableCell>Environment</TableCell>
                    <TableCell>Cluster</TableCell>
                    <TableCell>Test Category</TableCell>
                    <TableCell>Test Name</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Execution Time</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.results.map((result) => (
                    <TableRow key={result.id}>
                      <TableCell>
                        {format(new Date(result.timestamp), 'MMM dd, yyyy HH:mm')}
                      </TableCell>
                      <TableCell>
                        <Chip label={result.environment} size="small" />
                      </TableCell>
                      <TableCell>{result.cluster}</TableCell>
                      <TableCell>{result.test_category}</TableCell>
                      <TableCell>{result.test_name}</TableCell>
                      <TableCell>
                        <Chip 
                          label={result.status} 
                          color={getStatusColor(result.status)} 
                          size="small" 
                        />
                      </TableCell>
                      <TableCell>{result.execution_time_ms}ms</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>

          {data.results.length === 0 && (
            <Box sx={{ textAlign: 'center', py: 4 }}>
              <Typography color="textSecondary">
                No validation results found for the selected criteria.
              </Typography>
            </Box>
          )}
        </>
      )}
    </Box>
  );
};

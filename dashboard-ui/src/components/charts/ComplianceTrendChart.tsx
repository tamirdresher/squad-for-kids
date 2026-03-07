import React from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { Paper, Typography } from '@mui/material';
import { format } from 'date-fns';
import type { TrendDataPoint } from '../../types/api.types';

interface ComplianceTrendChartProps {
  data: TrendDataPoint[];
  title?: string;
}

export const ComplianceTrendChart: React.FC<ComplianceTrendChartProps> = ({ 
  data,
  title = 'Compliance Trend Over Time'
}) => {
  const chartData = data.map((point) => ({
    date: format(new Date(point.timestamp), 'MMM dd'),
    'Compliance Rate': point.compliance_rate,
    'Pass Rate': ((point.passed_tests / point.total_tests) * 100).toFixed(1),
  }));

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="date" />
          <YAxis domain={[0, 100]} />
          <Tooltip formatter={(value) => `${value}%`} />
          <Legend />
          <Line
            type="monotone"
            dataKey="Compliance Rate"
            stroke="#1976d2"
            strokeWidth={2}
            dot={{ r: 4 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </Paper>
  );
};

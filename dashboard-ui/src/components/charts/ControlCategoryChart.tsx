import React from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  Cell,
} from 'recharts';
import { Paper, Typography } from '@mui/material';
import type { ControlCategory } from '../../types/api.types';

interface ControlCategoryChartProps {
  categories: ControlCategory[];
  title?: string;
}

const getBarColor = (rate: number): string => {
  if (rate >= 95) return '#4caf50';
  if (rate >= 90) return '#ff9800';
  return '#f44336';
};

export const ControlCategoryChart: React.FC<ControlCategoryChartProps> = ({
  categories,
  title = 'Compliance by Category',
}) => {
  const chartData = categories.map((cat) => ({
    name: cat.category.length > 30 
      ? cat.category.substring(0, 30) + '...' 
      : cat.category,
    'Compliance Rate': cat.compliance_rate,
    fullName: cat.category,
  }));

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <ResponsiveContainer width="100%" height={400}>
        <BarChart data={chartData} layout="vertical">
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis type="number" domain={[0, 100]} />
          <YAxis dataKey="name" type="category" width={200} />
          <Tooltip 
            formatter={(value) => `${value}%`}
            labelFormatter={(label) => {
              const item = chartData.find(d => d.name === label);
              return item?.fullName || label;
            }}
          />
          <Legend />
          <Bar dataKey="Compliance Rate" name="Compliance Rate">
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={getBarColor(entry['Compliance Rate'])} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </Paper>
  );
};

import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';
import { Paper, Typography } from '@mui/material';

interface ComplianceDonutChartProps {
  passing: number;
  failing: number;
  title?: string;
}

const COLORS = {
  passing: '#4caf50',
  failing: '#f44336',
};

export const ComplianceDonutChart: React.FC<ComplianceDonutChartProps> = ({
  passing,
  failing,
  title = 'Control Status',
}) => {
  const total = passing + failing;
  const complianceRate = total > 0 ? ((passing / total) * 100).toFixed(1) : '0.0';

  const data = [
    { name: 'Passing', value: passing },
    { name: 'Failing', value: failing },
  ];

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <Typography variant="h3" align="center" color="primary" sx={{ my: 2 }}>
        {complianceRate}%
      </Typography>
      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={80}
            paddingAngle={5}
            dataKey="value"
          >
            {data.map((entry) => (
              <Cell 
                key={entry.name} 
                fill={entry.name === 'Passing' ? COLORS.passing : COLORS.failing} 
              />
            ))}
          </Pie>
          <Tooltip />
          <Legend />
        </PieChart>
      </ResponsiveContainer>
    </Paper>
  );
};

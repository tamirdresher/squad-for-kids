import React from 'react';
import { 
  Card, 
  CardContent, 
  Typography, 
  Box,
  LinearProgress 
} from '@mui/material';

interface StatsCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  color?: 'primary' | 'success' | 'error' | 'warning';
  progress?: number;
}

const colorMap = {
  primary: '#1976d2',
  success: '#4caf50',
  error: '#f44336',
  warning: '#ff9800',
};

export const StatsCard: React.FC<StatsCardProps> = ({
  title,
  value,
  subtitle,
  color = 'primary',
  progress,
}) => {
  return (
    <Card>
      <CardContent>
        <Typography color="textSecondary" gutterBottom variant="body2">
          {title}
        </Typography>
        <Typography variant="h4" component="div" sx={{ color: colorMap[color], mb: 1 }}>
          {value}
        </Typography>
        {subtitle && (
          <Typography variant="body2" color="textSecondary">
            {subtitle}
          </Typography>
        )}
        {progress !== undefined && (
          <Box sx={{ mt: 2 }}>
            <LinearProgress 
              variant="determinate" 
              value={progress} 
              color={color}
            />
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

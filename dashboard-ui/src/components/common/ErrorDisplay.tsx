import React from 'react';
import { Alert, AlertTitle, Box } from '@mui/material';

interface ErrorDisplayProps {
  error: Error | string;
  title?: string;
}

export const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ 
  error, 
  title = 'Error Loading Data' 
}) => {
  const message = typeof error === 'string' ? error : error.message;

  return (
    <Box sx={{ my: 4 }}>
      <Alert severity="error">
        <AlertTitle>{title}</AlertTitle>
        {message}
      </Alert>
    </Box>
  );
};

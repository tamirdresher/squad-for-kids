import React from 'react';
import { CircularProgress, Box, Typography } from '@mui/material';

interface LoadingSpinnerProps {
  message?: string;
}

export const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ 
  message = 'Loading...' 
}) => {
  return (
    <Box
      display="flex"
      flexDirection="column"
      alignItems="center"
      justifyContent="center"
      minHeight="400px"
    >
      <CircularProgress size={60} />
      <Typography variant="h6" sx={{ mt: 2 }} color="textSecondary">
        {message}
      </Typography>
    </Box>
  );
};

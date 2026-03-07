import React from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Typography,
} from '@mui/material';
import { format } from 'date-fns';
import type { RecentFailure } from '../../types/api.types';

interface RecentFailuresTableProps {
  failures: RecentFailure[];
  title?: string;
}

export const RecentFailuresTable: React.FC<RecentFailuresTableProps> = ({
  failures,
  title = 'Recent Failures',
}) => {
  if (failures.length === 0) {
    return (
      <Paper sx={{ p: 3 }}>
        <Typography variant="h6" gutterBottom>
          {title}
        </Typography>
        <Typography color="textSecondary">No recent failures</Typography>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        {title}
      </Typography>
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Control ID</TableCell>
              <TableCell>Control Name</TableCell>
              <TableCell>Failure Time</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {failures.map((failure, index) => (
              <TableRow key={`${failure.control_id}-${index}`}>
                <TableCell>
                  <Chip label={failure.control_id} size="small" />
                </TableCell>
                <TableCell>{failure.control_name}</TableCell>
                <TableCell>
                  {format(new Date(failure.failure_time), 'MMM dd, yyyy HH:mm')}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Paper>
  );
};

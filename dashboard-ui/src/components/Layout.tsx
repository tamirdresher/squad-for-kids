import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  AppBar,
  Box,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
  Container,
  Chip,
} from '@mui/material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import AssignmentIcon from '@mui/icons-material/Assignment';
import StorageIcon from '@mui/icons-material/Storage';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import SecurityIcon from '@mui/icons-material/Security';
import type { UserPermissions } from '../types/api.types';

interface LayoutProps {
  children: React.ReactNode;
  permissions: UserPermissions;
}

const drawerWidth = 240;

export const Layout: React.FC<LayoutProps> = ({ children, permissions }) => {
  const location = useLocation();

  const menuItems = [
    {
      text: 'Overview',
      icon: <DashboardIcon />,
      path: '/overview',
      visible: permissions.canViewDashboard,
    },
    {
      text: 'Control Detail',
      icon: <AssignmentIcon />,
      path: '/controls',
      visible: permissions.canViewControls,
    },
    {
      text: 'Environment View',
      icon: <StorageIcon />,
      path: '/environments',
      visible: permissions.canViewDashboard,
    },
    {
      text: 'Trend Analysis',
      icon: <TrendingUpIcon />,
      path: '/trends',
      visible: permissions.canViewAnalytics,
    },
  ];

  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar
        position="fixed"
        sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}
      >
        <Toolbar>
          <SecurityIcon sx={{ mr: 2 }} />
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
            FedRAMP Security Dashboard
          </Typography>
          <Chip 
            label={permissions.role} 
            color="secondary" 
            size="small"
          />
        </Toolbar>
      </AppBar>
      
      <Drawer
        variant="permanent"
        sx={{
          width: drawerWidth,
          flexShrink: 0,
          [`& .MuiDrawer-paper`]: {
            width: drawerWidth,
            boxSizing: 'border-box',
          },
        }}
      >
        <Toolbar />
        <Box sx={{ overflow: 'auto' }}>
          <List>
            {menuItems
              .filter((item) => item.visible)
              .map((item) => (
                <ListItem key={item.path} disablePadding>
                  <ListItemButton
                    component={Link}
                    to={item.path}
                    selected={location.pathname === item.path}
                  >
                    <ListItemIcon>{item.icon}</ListItemIcon>
                    <ListItemText primary={item.text} />
                  </ListItemButton>
                </ListItem>
              ))}
          </List>
        </Box>
      </Drawer>
      
      <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
        <Toolbar />
        <Container maxWidth="xl">
          {children}
        </Container>
      </Box>
    </Box>
  );
};

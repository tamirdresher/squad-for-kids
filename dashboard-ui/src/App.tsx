import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme, CssBaseline } from '@mui/material';
import { Layout } from './components/Layout';
import { OverviewPage } from './components/pages/OverviewPage';
import { ControlDetailPage } from './components/pages/ControlDetailPage';
import { EnvironmentViewPage } from './components/pages/EnvironmentViewPage';
import { TrendAnalysisPage } from './components/pages/TrendAnalysisPage';
import { LiveActivityPage } from './components/pages/LiveActivityPage';
import { useAuth } from './hooks/useAuth';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

const App: React.FC = () => {
  const { permissions, isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <div>Loading authentication...</div>;
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Layout permissions={permissions}>
          <Routes>
            {permissions.canViewDashboard && (
              <>
                <Route path="/" element={<OverviewPage />} />
                <Route path="/overview" element={<OverviewPage />} />
              </>
            )}
            
            {permissions.canViewControls && (
              <Route path="/controls" element={<ControlDetailPage />} />
            )}
            
            {permissions.canViewDashboard && (
              <Route path="/environments" element={<EnvironmentViewPage />} />
            )}
            
            {permissions.canViewAnalytics && (
              <Route path="/trends" element={<TrendAnalysisPage />} />
            )}
            
            {permissions.canViewDashboard && (
              <Route path="/activity" element={<LiveActivityPage />} />
            )}
            
            <Route
              path="*" 
              element={
                permissions.canViewDashboard 
                  ? <Navigate to="/overview" replace /> 
                  : <div>Access Denied</div>
              } 
            />
          </Routes>
        </Layout>
      </Router>
    </ThemeProvider>
  );
};

export default App;

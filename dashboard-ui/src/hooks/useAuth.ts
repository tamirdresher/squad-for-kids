import { useState, useEffect } from 'react';
import { UserPermissions } from '../types/api.types';
import { getRolePermissions, mockGetCurrentUserRole, parseJwtRole } from '../utils/rbac';

export const useAuth = () => {
  const [permissions, setPermissions] = useState<UserPermissions>({
    canViewDashboard: false,
    canViewControls: false,
    canViewAnalytics: false,
    canExportReports: false,
    role: 'Ops Viewer',
  });
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('azure_ad_token');
    
    if (token) {
      const role = parseJwtRole(token);
      if (role) {
        setPermissions(getRolePermissions(role));
        setIsAuthenticated(true);
        return;
      }
    }

    const mockRole = mockGetCurrentUserRole();
    setPermissions(getRolePermissions(mockRole));
    setIsAuthenticated(true);
  }, []);

  return { permissions, isAuthenticated };
};

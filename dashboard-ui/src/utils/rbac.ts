import { UserPermissions, UserRole } from '../types/api.types';

export const getRolePermissions = (role: UserRole): UserPermissions => {
  switch (role) {
    case 'Security Admin':
      return {
        canViewDashboard: true,
        canViewControls: true,
        canViewAnalytics: true,
        canExportReports: true,
        role,
      };
    case 'Security Engineer':
      return {
        canViewDashboard: true,
        canViewControls: true,
        canViewAnalytics: true,
        canExportReports: true,
        role,
      };
    case 'SRE':
      return {
        canViewDashboard: true,
        canViewControls: true,
        canViewAnalytics: true,
        canExportReports: false,
        role,
      };
    case 'Ops Viewer':
      return {
        canViewDashboard: true,
        canViewControls: false,
        canViewAnalytics: false,
        canExportReports: false,
        role,
      };
    case 'Auditor':
      return {
        canViewDashboard: false,
        canViewControls: false,
        canViewAnalytics: false,
        canExportReports: true,
        role,
      };
    default:
      return {
        canViewDashboard: false,
        canViewControls: false,
        canViewAnalytics: false,
        canExportReports: false,
        role: 'Ops Viewer',
      };
  }
};

export const parseJwtRole = (token: string): UserRole | null => {
  try {
    // Client-side role extraction for UI rendering only.
    // Authorization is enforced server-side; never trust client-parsed claims for access control.
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const payload = JSON.parse(atob(parts[1]));
    if (typeof payload !== 'object' || payload === null) return null;

    const roles: unknown[] = Array.isArray(payload.roles) ? payload.roles : [];
    
    if (roles.includes('FedRAMP.SecurityAdmin')) return 'Security Admin';
    if (roles.includes('FedRAMP.SecurityEngineer')) return 'Security Engineer';
    if (roles.includes('FedRAMP.SRE')) return 'SRE';
    if (roles.includes('FedRAMP.OpsViewer')) return 'Ops Viewer';
    if (roles.includes('FedRAMP.Auditor')) return 'Auditor';
    
    return null;
  } catch {
    return null;
  }
};

export const mockGetCurrentUserRole = (): UserRole => {
  if (process.env.NODE_ENV === 'development') {
    const mockRole = sessionStorage.getItem('mock_user_role');
    if (mockRole && isValidRole(mockRole)) {
      return mockRole as UserRole;
    }
  }
  return 'SRE';
};

const isValidRole = (role: string): boolean => {
  return ['Security Admin', 'Security Engineer', 'SRE', 'Ops Viewer', 'Auditor'].includes(role);
};

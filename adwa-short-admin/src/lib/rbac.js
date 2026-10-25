/**
 * RBAC Helper utilities for ADWA SHORT Admin
 */

export function getAdminRole(user) {
  if (!user) return null
  if (user.admin_role) return user.admin_role
  if (user.role === 'admin' || user.role === 'super_admin') return 'super_admin'
  if (user.role === 'staff') return 'staff'
  return user.role || null
}

export function isSuperAdmin(user) {
  return getAdminRole(user) === 'super_admin'
}

export function isStaff(user) {
  return getAdminRole(user) === 'staff'
}

export function isCreator(user) {
  if (!user) return false
  return user.role === 'creator' || user.admin_role === 'creator'
}

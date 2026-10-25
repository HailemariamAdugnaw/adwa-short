import { describe, it, expect } from 'vitest'
import { getAdminRole, isSuperAdmin, isStaff } from './rbac'

describe('RBAC utilities', () => {
  it('identifies super_admin role from admin_role field', () => {
    const user = { id: 1, role: 'admin', admin_role: 'super_admin' }
    expect(getAdminRole(user)).toBe('super_admin')
    expect(isSuperAdmin(user)).toBe(true)
    expect(isStaff(user)).toBe(false)
  })

  it('identifies staff role from admin_role field', () => {
    const user = { id: 2, role: 'staff', admin_role: 'staff' }
    expect(getAdminRole(user)).toBe('staff')
    expect(isSuperAdmin(user)).toBe(false)
    expect(isStaff(user)).toBe(true)
  })

  it('defaults legacy role="admin" to super_admin', () => {
    const user = { id: 3, role: 'admin' }
    expect(getAdminRole(user)).toBe('super_admin')
    expect(isSuperAdmin(user)).toBe(true)
  })

  it('handles null/undefined user safely', () => {
    expect(getAdminRole(null)).toBeNull()
    expect(isSuperAdmin(null)).toBe(false)
    expect(isStaff(null)).toBe(false)
  })
})

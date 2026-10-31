import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useAuthStore } from './store'
import { queryClient } from './queryClient'

describe('useAuthStore session & state destruction', () => {
  beforeEach(() => {
    useAuthStore.getState().logout()
    localStorage.clear()
    sessionStorage.clear()
    queryClient.clear()
  })

  it('correctly destroys state, tokens, and clears queryClient on logout', () => {
    // Populate store
    useAuthStore.getState().login({
      access_token: 'test-token',
      refresh_token: 'test-refresh',
      user: {
        id: 'user-1',
        role: 'super_admin',
        admin_role: 'super_admin',
        display_name: 'Admin User',
      },
    })

    expect(useAuthStore.getState().isAuthenticated).toBe(true)
    expect(useAuthStore.getState().user?.role).toBe('super_admin')

    const clearSpy = vi.spyOn(queryClient, 'clear')

    // Perform logout
    useAuthStore.getState().logout()

    expect(useAuthStore.getState().isAuthenticated).toBe(false)
    expect(useAuthStore.getState().user).toBeNull()
    expect(useAuthStore.getState().accessToken).toBeNull()
    expect(useAuthStore.getState().refreshToken).toBeNull()
    expect(clearSpy).toHaveBeenCalled()

    const saved = JSON.parse(localStorage.getItem('adwa-admin-auth') || '{}')
    expect(saved.state?.isAuthenticated).toBe(false)
    expect(saved.state?.user).toBeNull()
    expect(saved.state?.accessToken).toBeNull()

    clearSpy.mockRestore()
  })

  it('correctly handles nested role payload for creator upon login', () => {
    useAuthStore.getState().login({
      access_token: 'creator-token',
      refresh_token: 'creator-refresh',
      user: {
        id: 'creator-99',
        role: 'creator',
        display_name: 'Studio Creator',
      },
    })

    const state = useAuthStore.getState()
    expect(state.isAuthenticated).toBe(true)
    expect(state.user?.role).toBe('creator')
    expect(state.user?.admin_role).toBe('creator')
    expect(state.accessToken).toBe('creator-token')
  })

  it('correctly handles top-level role payload for admin upon login', () => {
    useAuthStore.getState().login({
      access_token: 'admin-token',
      refresh_token: 'admin-refresh',
      user_id: 'admin-1',
      role: 'admin',
      admin_role: 'super_admin',
      display_name: 'Platform Superadmin',
    })

    const state = useAuthStore.getState()
    expect(state.isAuthenticated).toBe(true)
    expect(state.user?.role).toBe('admin')
    expect(state.user?.admin_role).toBe('super_admin')
  })
})

import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import { queryClient } from './queryClient'

export const useAuthStore = create(
  persist(
    (set) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,
      setUser: (user) => set({ user }),
      setTokens: (accessToken, refreshToken) =>
        set({ accessToken, refreshToken, isAuthenticated: true }),
      login: (data) => {
        try {
          queryClient.clear()
        } catch {
          // ignore queryClient clearing errors during init
        }

        const rawUser = data.user || {}
        const role = data.role || rawUser.role || 'staff'
        const adminRole =
          data.admin_role ||
          rawUser.admin_role ||
          (role === 'admin' ? 'super_admin' : role)

        const u = {
          id: data.user_id || rawUser.id,
          role,
          admin_role: adminRole,
          display_name: data.display_name || rawUser.display_name,
          email: data.email || rawUser.email,
        }

        set({
          user: u,
          accessToken: data.access_token,
          refreshToken: data.refresh_token,
          isAuthenticated: true,
        })
      },
      logout: () => {
        try {
          queryClient.clear()
        } catch {
          // ignore queryClient clearing errors
        }

        try {
          localStorage.removeItem('adwa-admin-auth')
          sessionStorage.clear()
        } catch {
          // ignore storage clearing errors
        }

        set({ user: null, accessToken: null, refreshToken: null, isAuthenticated: false })
      },
    }),
    {
      name: 'adwa-admin-auth',
      storage: createJSONStorage(() => localStorage),
      partialize: (s) => ({
        user: s.user,
        accessToken: s.accessToken,
        refreshToken: s.refreshToken,
        isAuthenticated: s.isAuthenticated,
      }),
    },
  ),
)

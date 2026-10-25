import { useState } from 'react'
import { useNavigate, useLocation, Navigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import axios from 'axios'
import toast from 'react-hot-toast'
import { Clapperboard, Lock, ArrowRight, Loader2, User } from 'lucide-react'
import { useAuthStore } from '../lib/store'
import { errMsg } from '../lib/api'
import { Button } from '../components/ui/Button'
import { Input } from '../components/ui/Input'

export function Login() {
  const navigate = useNavigate()
  const location = useLocation()
  const login = useAuthStore((s) => s.login)
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)
  const [identifier, setIdentifier] = useState('admin@adwashort.com')
  const [password, setPassword] = useState('')

  const from = location.state?.from?.pathname ?? '/'

  const mutation = useMutation({
    mutationFn: async (creds) => {
      let deviceId = localStorage.getItem('adwa_device_id')
      if (!deviceId) {
        deviceId = crypto.randomUUID?.() ?? `dev-${Date.now()}`
        localStorage.setItem('adwa_device_id', deviceId)
      }
      const RAW_BASE = import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ?? ''
      const url = RAW_BASE ? `${RAW_BASE}/api/auth/login` : '/api/auth/login'
      const res = await axios.post(url, creds, {
        headers: { 'X-Device-Id': deviceId },
      })
      return res.data
    },
    onSuccess: (data) => {
      login(data)
      toast.success('Welcome back')
      const role = data.admin_role || (data.role === 'admin' ? 'super_admin' : data.role)
      if (role === 'staff') {
        navigate('/content/series', { replace: true })
      } else {
        navigate(from === '/login' ? '/' : from, { replace: true })
      }
    },
    onError: (err) => toast.error(errMsg(err, 'Login failed. Check credentials.')),
  })

  if (isAuthenticated) return <Navigate to={from} replace />

  const onSubmit = (e) => {
    e.preventDefault()
    if (!identifier.trim() || !password) return toast.error('Email, username, or phone and password required')
    mutation.mutate({
      identifier: identifier.trim(),
      phone: identifier.trim(),
      password,
    })
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-base">
      <div className="pointer-events-none absolute -top-1/4 left-1/2 h-[600px] w-[600px] -translate-x-1/2 rounded-full bg-accent/15 blur-[120px]" />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,rgba(0,0,0,0.8)_75%)]" />

      <div className="absolute left-6 top-6 flex items-center gap-2.5">
        <div className="flex h-9 w-9 items-center justify-center rounded-md bg-accent shadow-[0_0_24px_-4px_rgba(200,16,46,0.7)]">
          <Clapperboard className="h-5 w-5 text-white" />
        </div>
        <div className="leading-tight">
          <p className="text-sm font-extrabold tracking-wider text-white">
            ADWA <span className="text-accent">SHORT</span>
          </p>
          <p className="text-[10px] uppercase tracking-widest text-text-muted">Admin Console</p>
        </div>
      </div>

      <div className="relative w-full max-w-md px-6">
        <div className="card-surface p-8 animate-fade-in">
          <div className="mb-6 text-center">
            <h1 className="text-2xl font-bold text-text-primary">Operations Sign-In</h1>
            <p className="mt-1 text-xs text-text-secondary">
              Access the ADWA SHORT admin console.
            </p>
            <div className="mx-auto mt-3 h-0.5 w-12 rounded-full bg-accent" />
          </div>

          <form onSubmit={onSubmit} className="space-y-4">
            <Input
              label="Email, Username, or Phone"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              placeholder="admin@adwashort.com"
              leftIcon={<User className="h-4 w-4" />}
              autoComplete="username"
              required
            />
            <Input
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              leftIcon={<Lock className="h-4 w-4" />}
              autoComplete="current-password"
              required
            />
            <Button
              type="submit"
              fullWidth
              size="lg"
              loading={mutation.isPending}
              rightIcon={!mutation.isPending ? <ArrowRight className="h-4 w-4" /> : undefined}
            >
              {mutation.isPending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" /> Signing in…
                </>
              ) : (
                'Sign In'
              )}
            </Button>
          </form>

          <div className="mt-6 rounded-md border border-border bg-surface-2/60 p-3 text-[11px] leading-relaxed text-text-secondary">
            <p className="font-semibold text-text-primary">Default admin credentials</p>
            <p className="mt-1">Phone: <code className="text-accent">+251900000000</code></p>
            <p>Password: <code className="text-accent">admin123</code></p>
            <p className="mt-2 text-text-muted">Change immediately after first login.</p>
          </div>
        </div>

        <p className="mt-6 text-center text-[10px] text-text-muted">
          © 2025 Adwa Studios · All rights reserved · v1.0.0
        </p>
      </div>
    </div>
  )
}

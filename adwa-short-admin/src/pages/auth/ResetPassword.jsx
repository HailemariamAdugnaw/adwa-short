import { useState } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Clapperboard, Lock, ArrowLeft, Loader2, CheckCircle2, ArrowRight } from 'lucide-react'
import { resetPassword, errMsg } from '../../lib/api'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function ResetPassword() {
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token') || ''
  const navigate = useNavigate()

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [resetSuccess, setResetSuccess] = useState(false)

  const mutation = useMutation({
    mutationFn: (newPass) => resetPassword({ token, new_password: newPass }),
    onSuccess: (data) => {
      setResetSuccess(true)
      toast.success(data.message || 'Password successfully updated')
    },
    onError: (err) => toast.error(errMsg(err, 'Password reset failed. Token may be invalid or expired.')),
  })

  const onSubmit = (e) => {
    e.preventDefault()
    if (!token) return toast.error('Missing reset token in URL')
    if (password.length < 6) return toast.error('Password must be at least 6 characters')
    if (password !== confirmPassword) return toast.error('Passwords do not match')
    mutation.mutate(password)
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
          <p className="text-[10px] uppercase tracking-widest text-text-muted">Security Center</p>
        </div>
      </div>

      <div className="relative w-full max-w-md px-6">
        <div className="card-surface p-8 animate-fade-in">
          <div className="mb-6 text-center">
            <h1 className="text-2xl font-bold text-text-primary">Set New Password</h1>
            <p className="mt-1 text-xs text-text-secondary">
              Create a secure password to restore access to your account.
            </p>
            <div className="mx-auto mt-3 h-0.5 w-12 rounded-full bg-accent" />
          </div>

          {!token ? (
            <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-4 text-center text-xs text-amber-200">
              <p className="font-semibold">Invalid Recovery Link</p>
              <p className="mt-1 text-text-muted">
                No reset token was found in your URL. Please request a new recovery link.
              </p>
              <Link
                to="/forgot-password"
                className="mt-3 inline-block font-semibold text-accent hover:underline"
              >
                Request New Link
              </Link>
            </div>
          ) : !resetSuccess ? (
            <form onSubmit={onSubmit} className="space-y-4">
              <Input
                label="New Password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="At least 6 characters"
                leftIcon={<Lock className="h-4 w-4" />}
                autoComplete="new-password"
                required
              />

              <Input
                label="Confirm Password"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Re-type new password"
                leftIcon={<Lock className="h-4 w-4" />}
                autoComplete="new-password"
                required
              />

              <Button
                type="submit"
                fullWidth
                size="lg"
                loading={mutation.isPending}
                rightIcon={!mutation.isPending ? <ArrowRight className="h-4 w-4" /> : undefined}
              >
                {mutation.isPending ? 'Updating Password…' : 'Save New Password'}
              </Button>
            </form>
          ) : (
            <div className="space-y-4 text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                <CheckCircle2 className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-semibold text-text-primary">Password Reset Complete</p>
                <p className="mt-1 text-xs text-text-secondary">
                  Your password has been securely updated. You can now log into your account with your new credentials.
                </p>
              </div>

              <Button
                fullWidth
                onClick={() => navigate('/login')}
                rightIcon={<ArrowRight className="h-4 w-4" />}
              >
                Sign In Now
              </Button>
            </div>
          )}

          <div className="mt-6 text-center">
            <Link
              to="/login"
              className="inline-flex items-center gap-1.5 text-xs text-text-muted hover:text-text-primary transition-colors"
            >
              <ArrowLeft className="h-3.5 w-3.5" /> Back to Sign In
            </Link>
          </div>
        </div>

        <p className="mt-6 text-center text-[10px] text-text-muted">
          © 2025 Adwa Studios · Creator Portal & Admin Console
        </p>
      </div>
    </div>
  )
}

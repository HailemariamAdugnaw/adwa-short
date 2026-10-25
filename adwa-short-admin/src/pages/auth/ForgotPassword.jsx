import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Clapperboard, Mail, ArrowLeft, Loader2, CheckCircle2, ArrowRight } from 'lucide-react'
import { forgotPassword, errMsg } from '../../lib/api'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [resetUrl, setResetUrl] = useState('')

  const mutation = useMutation({
    mutationFn: (emailVal) => forgotPassword({ email: emailVal }),
    onSuccess: (data) => {
      setSubmitted(true)
      if (data.reset_url) {
        setResetUrl(data.reset_url)
      }
      toast.success(data.message || 'Recovery instructions sent')
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to send recovery link')),
  })

  const onSubmit = (e) => {
    e.preventDefault()
    if (!email.trim()) return toast.error('Please enter your email')
    mutation.mutate(email.trim())
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
          <p className="text-[10px] uppercase tracking-widest text-text-muted">Account Recovery</p>
        </div>
      </div>

      <div className="relative w-full max-w-md px-6">
        <div className="card-surface p-8 animate-fade-in">
          <div className="mb-6 text-center">
            <h1 className="text-2xl font-bold text-text-primary">Password Recovery</h1>
            <p className="mt-1 text-xs text-text-secondary">
              Enter your registered email address to receive a secure password reset link.
            </p>
            <div className="mx-auto mt-3 h-0.5 w-12 rounded-full bg-accent" />
          </div>

          {!submitted ? (
            <form onSubmit={onSubmit} className="space-y-4">
              <Input
                label="Account Email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="creator@adwashort.com"
                leftIcon={<Mail className="h-4 w-4" />}
                autoComplete="email"
                required
              />

              <Button
                type="submit"
                fullWidth
                size="lg"
                loading={mutation.isPending}
                rightIcon={!mutation.isPending ? <ArrowRight className="h-4 w-4" /> : undefined}
              >
                {mutation.isPending ? 'Sending Link…' : 'Send Reset Link'}
              </Button>
            </form>
          ) : (
            <div className="space-y-4 text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                <CheckCircle2 className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-semibold text-text-primary">Recovery Instructions Sent</p>
                <p className="mt-1 text-xs text-text-secondary leading-relaxed">
                  If <span className="font-mono text-accent">{email}</span> is registered in our platform, a secure password reset link has been dispatched.
                </p>
              </div>

              {resetUrl && (
                <div className="mt-4 rounded-md border border-accent/30 bg-accent/10 p-3 text-left text-xs">
                  <p className="font-semibold text-accent">Development Helper</p>
                  <p className="mt-0.5 text-text-muted">Click below to test your reset link directly:</p>
                  <Link
                    to={resetUrl}
                    className="mt-2 inline-flex items-center gap-1.5 text-xs font-bold text-accent hover:underline"
                  >
                    Open Reset Form <ArrowRight className="h-3 w-3" />
                  </Link>
                </div>
              )}
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

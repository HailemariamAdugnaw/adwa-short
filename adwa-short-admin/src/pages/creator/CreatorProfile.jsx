import { useState, useEffect } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  UserCircle,
  FileText,
  Lock,
  Save,
  ShieldCheck,
  Mail,
  Phone,
  Calendar,
  Sparkles,
  ExternalLink,
  Info,
} from 'lucide-react'
import { useCreatorPortalProfile } from '../../lib/hooks'
import { updateCreatorPortalProfile, errMsg } from '../../lib/api'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function CreatorProfile() {
  const qc = useQueryClient()
  const { data: profile, isLoading } = useCreatorPortalProfile()

  const [displayName, setDisplayName] = useState('')
  const [bio, setBio] = useState('')
  const [avatarUrl, setAvatarUrl] = useState('')
  const [phone, setPhone] = useState('')

  useEffect(() => {
    if (profile) {
      setDisplayName(profile.display_name || '')
      setBio(profile.bio || '')
      setAvatarUrl(profile.avatar_url || '')
      setPhone(profile.phone || '')
    }
  }, [profile])

  const mutation = useMutation({
    mutationFn: (payload) => updateCreatorPortalProfile(payload),
    onSuccess: () => {
      toast.success('Creator profile updated successfully')
      qc.invalidateQueries({ queryKey: ['creator', 'profile'] })
      qc.invalidateQueries({ queryKey: ['creator', 'dashboard'] })
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update profile')),
  })

  const onSubmit = (e) => {
    e.preventDefault()
    mutation.mutate({
      display_name: displayName.trim() || null,
      bio: bio.trim() || null,
      avatar_url: avatarUrl.trim() || null,
      phone: phone.trim() || null,
    })
  }

  if (isLoading) {
    return (
      <div className="flex h-96 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-text-primary">Profile & Contract Agreement</h1>
        <p className="mt-1 text-xs text-text-secondary">
          Update your public creator persona and review your legal revenue split agreement terms.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Profile Editor Form */}
        <div className="card-surface p-6 lg:col-span-2">
          <div className="mb-4 flex items-center justify-between border-b border-border pb-3">
            <div>
              <h2 className="text-sm font-bold text-text-primary">Creator Public Profile</h2>
              <p className="text-xs text-text-muted">Information visible across ADWA SHORT streaming apps.</p>
            </div>
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-accent/15 text-accent border border-accent/30 font-black text-sm">
              {(displayName || profile?.name || 'C')[0].toUpperCase()}
            </div>
          </div>

          <form onSubmit={onSubmit} className="space-y-4">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                label="Creator Display Name"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Stage name or production studio"
                leftIcon={<UserCircle className="h-4 w-4" />}
                required
              />

              <Input
                label="Direct Contact Phone"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+251911000000"
                leftIcon={<Phone className="h-4 w-4" />}
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1">
                <label className="text-xs font-medium text-text-secondary">Official Account Email</label>
                <div className="flex items-center gap-2 rounded-lg border border-border bg-surface-2 px-3 py-2 text-xs text-text-muted">
                  <Mail className="h-4 w-4 text-text-muted" />
                  <span className="font-mono">{profile?.email || 'N/A'}</span>
                  <Lock className="h-3.5 w-3.5 ml-auto text-text-muted" />
                </div>
                <p className="text-[10px] text-text-muted">Locked to your login account.</p>
              </div>

              <Input
                label="Profile Avatar URL"
                value={avatarUrl}
                onChange={(e) => setAvatarUrl(e.target.value)}
                placeholder="https://..."
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-medium text-text-secondary">Bio / Studio Synopsis</label>
              <textarea
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                rows={4}
                className="w-full rounded-lg border border-border bg-surface-2 p-3 text-xs text-text-primary placeholder:text-text-muted focus:border-accent focus:outline-none"
                placeholder="Brief biography, production credits, or filmmaker bio…"
              />
            </div>

            <div className="pt-2">
              <Button
                type="submit"
                loading={mutation.isPending}
                rightIcon={!mutation.isPending ? <Save className="h-4 w-4" /> : undefined}
              >
                {mutation.isPending ? 'Saving Profile…' : 'Save Profile Changes'}
              </Button>
            </div>
          </form>
        </div>

        {/* Read-Only Contract & Split Information */}
        <div className="space-y-6">
          <div className="card-surface p-6 border-l-4 border-l-amber-500">
            <div className="mb-3 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-amber-400" />
                <h3 className="text-xs font-bold uppercase tracking-wider text-text-primary">
                  Agreed Revenue Split
                </h3>
              </div>
              <Badge tone="accent">Read-Only</Badge>
            </div>

            <div className="mt-4 rounded-xl border border-amber-500/20 bg-amber-500/10 p-4 text-center">
              <span className="text-xs font-medium text-amber-300">Your Commission Rate</span>
              <p className="mt-1 text-3xl font-black text-amber-400">
                {profile?.default_revenue_split_pct}%
              </p>
              <p className="mt-1 text-[11px] text-amber-200/80">
                Net split credited directly to your account
              </p>
            </div>

            <div className="mt-4 space-y-2.5 text-xs text-text-secondary">
              <div className="flex items-center justify-between border-b border-border/60 pb-2">
                <span className="text-text-muted">ADWA Share:</span>
                <span className="font-bold text-text-primary">
                  {100 - (profile?.default_revenue_split_pct || 50)}%
                </span>
              </div>
              <div className="flex items-center justify-between border-b border-border/60 pb-2">
                <span className="text-text-muted">Contract Status:</span>
                <Badge tone="success">Active & Enforced</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-text-muted">Signed Date:</span>
                <span className="font-mono text-text-primary">
                  {profile?.contract_signed_date
                    ? new Date(profile.contract_signed_date).toLocaleDateString()
                    : 'On File'}
                </span>
              </div>
            </div>

            <div className="mt-4 rounded-lg border border-border bg-surface-2/60 p-3 text-[11px] text-text-muted leading-relaxed flex items-start gap-2">
              <Info className="h-4 w-4 text-accent shrink-0 mt-0.5" />
              <span>
                Revenue split percentages and contractual rates are governed by your partner agreement and can only be altered by platform Super Administrators.
              </span>
            </div>
          </div>

          {/* Custom Content Split Overrides */}
          {profile?.split_rules && profile.split_rules.length > 0 && (
            <div className="card-surface p-5">
              <h4 className="text-xs font-bold text-text-primary uppercase tracking-wider mb-2">
                Custom Content Split Overrides
              </h4>
              <div className="space-y-2">
                {profile.split_rules.map((rule) => (
                  <div
                    key={rule.id}
                    className="flex items-center justify-between rounded-lg border border-border bg-surface-2 p-2.5 text-xs"
                  >
                    <span className="text-text-muted font-medium">
                      {rule.episode_id ? `Episode #${rule.episode_id}` : `Series #${rule.series_id}`}
                    </span>
                    <Badge tone="accent">{rule.creator_share_pct}% Creator</Badge>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

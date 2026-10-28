import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Save, X } from 'lucide-react'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Select } from '../ui/Select'
import { FileDropzone } from '../ui/FileDropzone'
import { Card } from '../ui/Card'
import { upload, post, put, errMsg } from '../../lib/api'
import { useAuthStore } from '../../lib/store'

const PAYMENT_METHODS = [
  { value: 'cbe', label: 'Commercial Bank of Ethiopia (CBE)' },
  { value: 'cbe_birr', label: 'CBE Birr (Mobile)' },
  { value: 'bank', label: 'Other Bank Transfer' },
  { value: 'cheque', label: 'Cheque' },
  { value: 'cash', label: 'Cash' },
  { value: 'other', label: 'Other' },
]

export function CreatorForm({ initial, onSaved, onCancel }) {
  const qc = useQueryClient()
  const user = useAuthStore((s) => s.user)
  const adminRole = user?.admin_role || (user?.role === 'admin' ? 'super_admin' : user?.role)
  const isSuperAdmin = adminRole === 'super_admin'
  const isEdit = !!initial

  const [form, setForm] = useState({
    name: '',
    phone: '',
    email: '',
    display_name: '',
    avatar_url: '',
    bank_name: '',
    bank_account_name: '',
    bank_account_number: '',
    payment_method: 'bank',
    legal_contract_url: '',
    contract_signed_date: '',
    default_revenue_split_pct: 50,
    is_active: true,
  })
  const [uploadingAvatar, setUploadingAvatar] = useState(false)
  const [uploadingContract, setUploadingContract] = useState(false)
  const [contractFile, setContractFile] = useState(null)

  useEffect(() => {
    if (!initial) return
    setForm({
      name: initial.name ?? '',
      phone: initial.phone ?? '',
      email: initial.email ?? '',
      display_name: initial.display_name ?? '',
      avatar_url: initial.avatar_url ?? '',
      bank_name: initial.bank_name ?? '',
      bank_account_name: initial.bank_account_name ?? '',
      bank_account_number: initial.bank_account_number ?? '',
      payment_method: initial.payment_method ?? 'bank',
      legal_contract_url: initial.legal_contract_url ?? '',
      contract_signed_date: initial.contract_signed_date
        ? String(initial.contract_signed_date).slice(0, 10)
        : '',
      default_revenue_split_pct:
        initial.default_revenue_split_pct ?? initial.default_split_pct ?? 50,
      is_active: initial.is_active ?? true,
    })
  }, [initial])

  const mutation = useMutation({
    mutationFn: async (payload) => {
      const body = { ...payload }
      if (!isSuperAdmin) {
        delete body.default_revenue_split_pct
      }
      if (isEdit && initial) return put(`/creators/${initial.id}`, body)
      return post('/creators', body)
    },
    onSuccess: (saved) => {
      toast.success(isEdit ? 'Split updated' : 'Creator created')
      qc.invalidateQueries({ queryKey: ['creators'] })
      if (initial?.id) {
        qc.invalidateQueries({ queryKey: ['creators', String(initial.id)] })
        qc.invalidateQueries({ queryKey: ['creators', initial.id] })
      }
      onSaved?.(saved)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save creator')),
  })

  const uploadAvatar = async (file) => {
    setUploadingAvatar(true)
    try {
      const res = await upload('/uploads/poster', file)
      setForm((f) => ({ ...f, avatar_url: res.url }))
      toast.success('Avatar uploaded')
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
    } finally {
      setUploadingAvatar(false)
    }
  }

  const uploadContract = async (file) => {
    setUploadingContract(true)
    setContractFile(file)
    try {
      const res = await upload('/uploads/video', file)
      setForm((f) => ({ ...f, legal_contract_url: res.url }))
      toast.success('Contract uploaded')
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
      setContractFile(null)
    } finally {
      setUploadingContract(false)
    }
  }

  const onSubmit = (e) => {
    e.preventDefault()
    if (!form.name.trim()) return toast.error('Name is required')
    if (!form.phone.trim()) return toast.error('Phone is required')
    const pct = Number(form.default_revenue_split_pct)
    if (Number.isNaN(pct) || pct < 0 || pct > 100) {
      return toast.error('Default split must be between 0 and 100')
    }
    const payload = {
      name: form.name,
      phone: form.phone,
      email: form.email || null,
      display_name: form.display_name || null,
      avatar_url: form.avatar_url || null,
      bank_name: form.bank_name || null,
      bank_account_name: form.bank_account_name || null,
      bank_account_number: form.bank_account_number || null,
      payment_method: form.payment_method || null,
      legal_contract_url: form.legal_contract_url || null,
      contract_signed_date: form.contract_signed_date || null,
      default_revenue_split_pct: pct,
      is_active: form.is_active,
    }
    if (!payload.contract_signed_date) delete payload.contract_signed_date
    mutation.mutate(payload)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Profile
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Full Name"
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            placeholder="e.g. Selam Tesfaye"
            required
          />
          <Input
            label="Display Name"
            value={form.display_name}
            onChange={(e) => setForm((f) => ({ ...f, display_name: e.target.value }))}
            placeholder="Public stage name"
          />
          <Input
            label="Phone"
            value={form.phone}
            onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
            placeholder="+251912345678"
            required
          />
          <Input
            label="Email"
            type="email"
            value={form.email}
            onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
            placeholder="name@example.com"
          />
          <div className="md:col-span-2">
            <FileDropzone
              label="Avatar"
              accept="image"
              previewAspect="poster"
              currentUrl={form.avatar_url || null}
              uploading={uploadingAvatar}
              onFile={uploadAvatar}
              onClear={() => setForm((f) => ({ ...f, avatar_url: '' }))}
              helperText="JPG/PNG · square or 2:3"
            />
          </div>
        </div>
      </Card>

      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Bank &amp; Payment Details
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Bank Name"
            value={form.bank_name}
            onChange={(e) => setForm((f) => ({ ...f, bank_name: e.target.value }))}
            placeholder="e.g. Commercial Bank of Ethiopia"
          />
          <Input
            label="Account Name"
            value={form.bank_account_name}
            onChange={(e) => setForm((f) => ({ ...f, bank_account_name: e.target.value }))}
            placeholder="Name on the account"
          />
          <Input
            label="Account Number"
            value={form.bank_account_number}
            onChange={(e) => setForm((f) => ({ ...f, bank_account_number: e.target.value }))}
            placeholder="0123456789012"
          />
          <Select
            label="Payment Method"
            value={form.payment_method}
            onChange={(e) => setForm((f) => ({ ...f, payment_method: e.target.value }))}
          >
            {PAYMENT_METHODS.map((m) => (
              <option key={m.value} value={m.value} className="bg-surface">
                {m.label}
              </option>
            ))}
          </Select>
        </div>
      </Card>

      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Contract &amp; Split
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Contract Date"
            type="date"
            value={form.contract_signed_date}
            onChange={(e) => setForm((f) => ({ ...f, contract_signed_date: e.target.value }))}
          />
          {isSuperAdmin ? (
            <Input
              label="Default Revenue Split (%)"
              type="number"
              min={0}
              max={100}
              value={form.default_revenue_split_pct}
              onChange={(e) =>
                setForm((f) => ({ ...f, default_revenue_split_pct: Number(e.target.value) }))
              }
              hint="Creator's default share of revenue (0–100). Platform gets the remainder."
            />
          ) : (
            <div className="flex flex-col justify-center rounded-md border border-border bg-surface-2/40 px-3 py-2 text-xs">
              <span className="text-text-secondary font-medium">Default Revenue Split</span>
              <span className="mt-1 font-semibold text-text-primary">
                {form.default_revenue_split_pct}% Creator / {100 - form.default_revenue_split_pct}% Platform
              </span>
              <span className="mt-0.5 text-[10px] text-text-muted">Managed exclusively by Super Admin</span>
            </div>
          )}
          <div className="md:col-span-2">
            <FileDropzone
              label="Contract Document (PDF)"
              accept="all"
              previewType="video"
              previewAspect="vertical"
              currentUrl={form.legal_contract_url || null}
              previewFile={contractFile}
              uploading={uploadingContract}
              onFile={uploadContract}
              onClear={() => {
                setForm((f) => ({ ...f, legal_contract_url: '' }))
                setContractFile(null)
              }}
              helperText="PDF · signed creator contract"
            />
          </div>
          <label className="flex h-12 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-2 hover:border-border-strong md:col-span-2">
            <span className="text-sm font-medium text-text-primary">Active</span>
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
              className="h-4 w-4 accent-accent"
            />
          </label>
        </div>
      </Card>

      <div className="sticky bottom-0 flex items-center justify-end gap-2 border-t border-border bg-base/95 px-4 py-3 backdrop-blur">
        <Button
          type="button"
          variant="ghost"
          onClick={() => (onCancel ? onCancel() : null)}
          leftIcon={<X className="h-4 w-4" />}
        >
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending} leftIcon={<Save className="h-4 w-4" />}>
          {isEdit ? 'Save Changes' : 'Create Creator'}
        </Button>
      </div>
    </form>
  )
}

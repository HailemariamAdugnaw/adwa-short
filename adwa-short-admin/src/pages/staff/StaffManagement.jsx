import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Users,
  ShieldCheck,
  UserPlus,
  Pencil,
  Trash2,
  CheckCircle2,
  Ban,
  Lock,
  Mail,
  Phone,
  KeyRound,
  Shield,
  Film,
  History,
} from 'lucide-react'
import { useStaffList } from '../../lib/hooks'
import { createStaff, updateStaff, toggleStaffActive, deleteStaff, errMsg } from '../../lib/api'
import { useAuthStore } from '../../lib/store'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Select } from '../../components/ui/Select'
import { Badge } from '../../components/ui/Badge'
import { Modal } from '../../components/ui/Modal'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { EmptyState } from '../../components/ui/EmptyState'
import { StatCard } from '../../components/ui/StatCard'
import {
  Table,
  TBody,
  TD,
  TH,
  THead,
  TR,
  SkeletonRow,
  EmptyRow,
} from '../../components/ui/Table'
import { formatDate, initials } from '../../lib/format'

export function StaffManagement() {
  const qc = useQueryClient()
  const currentUser = useAuthStore((s) => s.user)
  const { data: staffList, isLoading, isError } = useStaffList()

  const [modalOpen, setModalOpen] = useState(false)
  const [editingStaff, setEditingStaff] = useState(null)

  const [confirmToggle, setConfirmToggle] = useState(null)
  const [confirmDelete, setConfirmDelete] = useState(null)

  // Form State
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [roleLabel, setRoleLabel] = useState('staff')

  const openCreateModal = () => {
    setEditingStaff(null)
    setName('')
    setEmail('')
    setPhone('')
    setPassword('')
    setRoleLabel('staff')
    setModalOpen(true)
  }

  const openEditModal = (staff) => {
    setEditingStaff(staff)
    setName(staff.name || '')
    setEmail(staff.email || '')
    setPhone(staff.phone || '')
    setPassword('')
    setRoleLabel(staff.role_label || 'staff')
    setModalOpen(true)
  }

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (editingStaff) {
        return updateStaff(editingStaff.id, {
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim() || undefined,
          password: password ? password : undefined,
          role_label: roleLabel,
        })
      } else {
        return createStaff({
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim() || undefined,
          password: password,
          role_label: roleLabel,
          permissions: roleLabel === 'super_admin' ? '*' : 'content',
        })
      }
    },
    onSuccess: () => {
      toast.success(editingStaff ? 'Staff account updated' : 'New staff member added')
      qc.invalidateQueries({ queryKey: ['admin', 'staff'] })
      setModalOpen(false)
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to save staff account')),
  })

  const toggleMutation = useMutation({
    mutationFn: async (staff) => toggleStaffActive(staff.id),
    onSuccess: (updated) => {
      toast.success(updated.is_active ? 'Staff account activated' : 'Staff account deactivated')
      qc.invalidateQueries({ queryKey: ['admin', 'staff'] })
      setConfirmToggle(null)
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to update status')),
  })

  const deleteMutation = useMutation({
    mutationFn: async (staff) => deleteStaff(staff.id),
    onSuccess: () => {
      toast.success('Staff account deleted')
      qc.invalidateQueries({ queryKey: ['admin', 'staff'] })
      setConfirmDelete(null)
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to delete staff account')),
  })

  const items = Array.isArray(staffList) ? staffList : []
  const totalStaff = items.length
  const superAdminCount = items.filter((s) => s.role_label === 'super_admin').length
  const staffEditorCount = items.filter((s) => s.role_label === 'staff').length
  const activeCount = items.filter((s) => s.is_active).length

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-accent-soft text-accent">
              <ShieldCheck className="h-5 w-5" />
            </span>
            <h2 className="text-xl font-bold text-text-primary">Staff & RBAC Management</h2>
          </div>
          <p className="mt-1 text-sm text-text-secondary">
            Manage console access credentials, assign roles (Super Admin vs. Content Staff), and revoke access.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Link to="/staff/activity">
            <Button
              variant="secondary"
              leftIcon={<History className="h-4 w-4" />}
            >
              Activity Audit Log
            </Button>
          </Link>
          <Button
            leftIcon={<UserPlus className="h-4 w-4" />}
            onClick={openCreateModal}
          >
            Add Staff Member
          </Button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Total Staff & Admins"
          value={String(totalStaff)}
          icon={<Users className="h-5 w-5 text-accent" />}
          hint="Registered console users"
          loading={isLoading}
        />
        <StatCard
          label="Super Admins"
          value={String(superAdminCount)}
          icon={<Shield className="h-5 w-5 text-purple-400" />}
          hint="Full platform privileges"
          loading={isLoading}
        />
        <StatCard
          label="Content Staff"
          value={String(staffEditorCount)}
          icon={<Film className="h-5 w-5 text-emerald-400" />}
          hint="Content operations only"
          loading={isLoading}
        />
        <StatCard
          label="Active Accounts"
          value={`${activeCount} / ${totalStaff}`}
          icon={<CheckCircle2 className="h-5 w-5 text-sky-400" />}
          hint="Permitted sign-ins"
          loading={isLoading}
        />
      </div>

      {/* Staff Table */}
      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-4">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Console Staff Directory</CardTitle>
              <p className="mt-0.5 text-xs text-text-muted">
                Staff members authenticate via JWT using email or phone and manage assigned content.
              </p>
            </div>
          </div>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>Staff Member</TH>
              <TH>Contact</TH>
              <TH>Role</TH>
              <TH>Permissions</TH>
              <TH>Status</TH>
              <TH>Created</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={4} />
            ) : items.length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={Users}
                  title="No staff accounts"
                  description="Add staff members to delegate content management tasks."
                />
              </EmptyRow>
            ) : (
              items.map((s) => {
                const isCurrent = s.user_id === currentUser?.id || s.user_id === currentUser?.user_id
                const isSuper = s.role_label === 'super_admin'
                return (
                  <TR key={s.id}>
                    <TD>
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 font-bold text-xs text-text-primary border border-border">
                          {initials(s.name, s.email)}
                        </div>
                        <div>
                          <div className="flex items-center gap-1.5 font-medium text-text-primary">
                            <span>{s.name}</span>
                            {isCurrent && (
                              <span className="rounded bg-accent/15 px-1.5 py-0.2 text-[9px] font-bold text-accent">
                                You
                              </span>
                            )}
                          </div>
                          <p className="text-[10px] text-text-muted">User ID: #{s.user_id}</p>
                        </div>
                      </div>
                    </TD>
                    <TD>
                      <div className="text-xs space-y-0.5">
                        <div className="flex items-center gap-1 text-text-primary font-mono">
                          <Mail className="h-3 w-3 text-text-muted" />
                          <span>{s.email || '—'}</span>
                        </div>
                        {s.phone && (
                          <div className="flex items-center gap-1 text-text-muted text-[11px] font-mono">
                            <Phone className="h-3 w-3" />
                            <span>{s.phone}</span>
                          </div>
                        )}
                      </div>
                    </TD>
                    <TD>
                      {isSuper ? (
                        <Badge tone="accent" className="font-semibold">
                          Super Admin
                        </Badge>
                      ) : (
                        <Badge tone="success" className="font-semibold">
                          Staff
                        </Badge>
                      )}
                    </TD>
                    <TD>
                      <span className="text-xs text-text-secondary">
                        {isSuper ? 'Full System & Financials' : 'Content Management'}
                      </span>
                    </TD>
                    <TD>
                      {s.is_active ? (
                        <Badge tone="success">Active</Badge>
                      ) : (
                        <Badge tone="danger">Disabled</Badge>
                      )}
                    </TD>
                    <TD className="text-xs text-text-muted">{formatDate(s.created_at)}</TD>
                    <TD>
                      <div className="flex items-center justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Edit staff details"
                          onClick={() => openEditModal(s)}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          title={s.is_active ? 'Disable account' : 'Enable account'}
                          disabled={isCurrent}
                          onClick={() => setConfirmToggle(s)}
                        >
                          {s.is_active ? (
                            <Ban className="h-4 w-4 text-warning" />
                          ) : (
                            <CheckCircle2 className="h-4 w-4 text-success" />
                          )}
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Delete staff account"
                          disabled={isCurrent}
                          onClick={() => setConfirmDelete(s)}
                        >
                          <Trash2 className="h-4 w-4 text-danger" />
                        </Button>
                      </div>
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </Card>

      {/* Create / Edit Staff Modal */}
      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingStaff ? `Edit Staff: ${editingStaff.name}` : 'Add New Staff Member'}
        description="Configure credentials and access privileges for console operations."
        size="md"
      >
        <form
          onSubmit={(e) => {
            e.preventDefault()
            if (!name.trim()) return toast.error('Full name is required')
            if (!email.trim()) return toast.error('Email address is required')
            if (!editingStaff && !password) return toast.error('Password is required for new accounts')
            saveMutation.mutate()
          }}
          className="space-y-4"
        >
          <Input
            label="Full Name"
            placeholder="e.g. Jane Doe"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Input
              label="Email Address"
              type="email"
              placeholder="jane@adwashort.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              leftIcon={<Mail className="h-4 w-4" />}
              required
            />
            <Input
              label="Phone Number (Optional)"
              placeholder="+251911223344"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              leftIcon={<Phone className="h-4 w-4" />}
            />
          </div>

          <Input
            label={editingStaff ? 'New Password (Leave blank to keep unchanged)' : 'Initial Password'}
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            leftIcon={<KeyRound className="h-4 w-4" />}
            required={!editingStaff}
          />

          <div>
            <label className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-text-secondary">
              Role & Permissions
            </label>
            <Select
              value={roleLabel}
              onChange={(e) => setRoleLabel(e.target.value)}
              options={[
                { value: 'staff', label: 'Staff — Content operations only (Series, Episodes, Categories)' },
                { value: 'super_admin', label: 'Super Admin — Full system, revenue, and staff management' },
              ]}
            />
          </div>

          <div className="rounded-lg border border-border bg-surface-2/40 p-3 text-xs text-text-secondary space-y-1">
            <p className="font-semibold text-text-primary">
              {roleLabel === 'super_admin' ? 'Super Admin Privileges:' : 'Staff Member Privileges:'}
            </p>
            {roleLabel === 'super_admin' ? (
              <p>Has unrestricted control: Content management, financial ledgers, creator payouts, split configurator, user balances, and staff account management.</p>
            ) : (
              <p>Allowed to create categories, add series, upload video episodes, and manage media assets. Sensitive financial tabs (Revenue, Payouts, Splits) and Staff Management remain strictly inaccessible.</p>
            )}
          </div>

          <div className="flex items-center justify-end gap-2 pt-2">
            <Button type="button" variant="ghost" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" loading={saveMutation.isPending}>
              {editingStaff ? 'Save Changes' : 'Create Staff Member'}
            </Button>
          </div>
        </form>
      </Modal>

      {/* Confirm Deactivation */}
      <ConfirmDialog
        open={!!confirmToggle}
        title={confirmToggle?.is_active ? 'Deactivate Staff Account?' : 'Activate Staff Account?'}
        description={
          confirmToggle?.is_active
            ? `"${confirmToggle?.name}" will be immediately locked out from the admin console.`
            : `"${confirmToggle?.name}" will regain access to the admin console.`
        }
        confirmLabel={confirmToggle?.is_active ? 'Deactivate' : 'Activate'}
        variant={confirmToggle?.is_active ? 'danger' : 'primary'}
        onConfirm={() => confirmToggle && toggleMutation.mutate(confirmToggle)}
        onCancel={() => setConfirmToggle(null)}
        loading={toggleMutation.isPending}
      />

      {/* Confirm Deletion */}
      <ConfirmDialog
        open={!!confirmDelete}
        title="Delete Staff Member?"
        description={`Are you sure you want to delete "${confirmDelete?.name}"? This will permanently remove their console credentials and access.`}
        confirmLabel="Delete Account"
        variant="danger"
        onConfirm={() => confirmDelete && deleteMutation.mutate(confirmDelete)}
        onCancel={() => setConfirmDelete(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}

import { useState } from 'react'
import { Link } from 'react-router-dom'
import {
  History,
  Search,
  Filter,
  UserCheck,
  Shield,
  Film,
  Layers,
  FolderTree,
  Upload,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  AlertCircle,
  FileText,
} from 'lucide-react'
import { useStaffActivity, useStaffList } from '../../lib/hooks'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Select } from '../../components/ui/Select'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
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
import { formatDateTime, formatRelative, initials } from '../../lib/format'

const ACTION_TONES = {
  create: 'success',
  publish: 'success',
  update: 'warning',
  toggle_active: 'warning',
  delete: 'danger',
  unpublish: 'danger',
  upload: 'info',
}

const ENTITY_ICONS = {
  series: Film,
  episode: Layers,
  category: FolderTree,
  media: Upload,
  staff: Shield,
}

export function StaffActivityLog() {
  const [page, setPage] = useState(1)
  const [staffId, setStaffId] = useState('')
  const [action, setAction] = useState('')
  const [entityType, setEntityType] = useState('')
  const [searchQuery, setSearchQuery] = useState('')

  const { data: staffList } = useStaffList()
  const { data, isLoading, isError, refetch } = useStaffActivity({
    staff_id: staffId ? Number(staffId) : undefined,
    action: action || undefined,
    entity_type: entityType || undefined,
    q: searchQuery.trim() || undefined,
    page,
    limit: 30,
  })

  const items = Array.isArray(data?.items) ? data.items : []
  const total = data?.total ?? 0
  const totalPages = Math.max(1, Math.ceil(total / 30))

  const staffOptions = [
    { value: '', label: 'All Staff Members' },
    ...(staffList || []).map((s) => ({
      value: String(s.user_id),
      label: `${s.name} (${s.email || s.phone})`,
    })),
  ]

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2 text-xs text-text-muted mb-1">
            <Link to="/staff" className="hover:text-text-primary transition-colors flex items-center gap-1">
              <ChevronLeft className="h-3.5 w-3.5" /> Staff Management
            </Link>
            <span>/</span>
            <span className="text-text-primary font-medium">Activity Audit Trail</span>
          </div>
          <h2 className="text-xl font-bold text-text-primary flex items-center gap-2">
            <History className="h-5 w-5 text-accent" />
            Staff Activity &amp; Audit Trail
          </h2>
          <p className="text-sm text-text-secondary">
            Super admin monitoring for content additions, episode uploads, category edits, and staff actions.
          </p>
        </div>
        <Button
          variant="secondary"
          size="sm"
          leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
          onClick={() => refetch()}
        >
          Refresh Log
        </Button>
      </div>

      {/* Filter Controls */}
      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Input
            label="Search Activity"
            placeholder="Search details or names..."
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value)
              setPage(1)
            }}
            leftIcon={<Search className="h-4 w-4" />}
          />
          <Select
            label="Filter by Staff Operator"
            value={staffId}
            onChange={(e) => {
              setStaffId(e.target.value)
              setPage(1)
            }}
            options={staffOptions}
          />
          <Select
            label="Filter by Action"
            value={action}
            onChange={(e) => {
              setAction(e.target.value)
              setPage(1)
            }}
            options={[
              { value: '', label: 'All Actions' },
              { value: 'create', label: 'Create' },
              { value: 'update', label: 'Update' },
              { value: 'delete', label: 'Delete' },
              { value: 'publish', label: 'Publish' },
              { value: 'unpublish', label: 'Unpublish' },
              { value: 'upload', label: 'Upload' },
            ]}
          />
          <Select
            label="Filter by Entity"
            value={entityType}
            onChange={(e) => {
              setEntityType(e.target.value)
              setPage(1)
            }}
            options={[
              { value: '', label: 'All Entities' },
              { value: 'series', label: 'Series' },
              { value: 'episode', label: 'Episode' },
              { value: 'category', label: 'Category' },
              { value: 'media', label: 'Media Uploads' },
              { value: 'staff', label: 'Staff Management' },
            ]}
          />
        </div>
      </Card>

      {/* Audit Log Table */}
      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-3 flex items-center justify-between">
          <CardTitle className="text-sm font-semibold">
            Recorded Action History ({total} event{total === 1 ? '' : 's'})
          </CardTitle>
          {page > 1 && (
            <span className="text-xs text-text-muted">
              Page {page} of {totalPages}
            </span>
          )}
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH className="w-44">Timestamp</TH>
              <TH className="min-w-[200px]">Operator</TH>
              <TH className="w-28 text-center">Action</TH>
              <TH className="w-32 text-center">Entity</TH>
              <TH className="min-w-[300px]">Activity Details</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={5} rows={8} />
            ) : isError ? (
              <EmptyRow colSpan={5}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Failed to load audit activity.</p>
                  <Button size="sm" variant="ghost" onClick={() => refetch()}>
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : items.length === 0 ? (
              <EmptyRow colSpan={5}>
                <EmptyState
                  icon={History}
                  title="No activity recorded"
                  description="Staff actions matching criteria will appear here."
                />
              </EmptyRow>
            ) : (
              items.map((log) => {
                const tone = ACTION_TONES[log.action] || 'neutral'
                const EntityIcon = ENTITY_ICONS[log.entity_type] || FileText
                return (
                  <TR key={log.id} className="hover:bg-surface-2/40 transition-colors">
                    <TD className="text-xs whitespace-nowrap">
                      <div className="font-mono text-text-primary">{formatDateTime(log.created_at)}</div>
                      <div className="text-[11px] text-text-muted">{formatRelative(log.created_at)}</div>
                    </TD>
                    <TD>
                      <div className="flex items-center gap-2.5">
                        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent/20 text-xs font-bold text-accent">
                          {initials(log.admin_name, log.admin_email)}
                        </div>
                        <div className="min-w-0">
                          <div className="font-medium text-text-primary text-xs truncate">
                            {log.admin_name}
                          </div>
                          <div className="flex items-center gap-1.5 mt-0.5">
                            <span className="text-[10px] text-text-muted truncate">
                              {log.admin_email || 'No email'}
                            </span>
                            <span
                              className={`rounded px-1 py-0.2 text-[9px] font-semibold uppercase ${
                                log.admin_role === 'super_admin'
                                  ? 'bg-accent/15 text-accent'
                                  : 'bg-emerald-500/15 text-emerald-400'
                              }`}
                            >
                              {log.admin_role === 'super_admin' ? 'Super' : 'Staff'}
                            </span>
                          </div>
                        </div>
                      </div>
                    </TD>
                    <TD className="text-center">
                      <Badge tone={tone} className="uppercase text-[10px] tracking-wider font-semibold">
                        {log.action}
                      </Badge>
                    </TD>
                    <TD className="text-center">
                      <span className="inline-flex items-center gap-1.5 rounded-md border border-border bg-surface-2 px-2 py-0.5 text-xs text-text-secondary capitalize font-medium">
                        <EntityIcon className="h-3.5 w-3.5 text-text-muted" />
                        {log.entity_type}
                      </span>
                    </TD>
                    <TD className="text-xs">
                      <p className="font-medium text-text-primary">{log.details || '—'}</p>
                      {log.entity_id && (
                        <span className="font-mono text-[10px] text-text-muted">
                          ID: #{log.entity_id}
                        </span>
                      )}
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>

        {/* Pagination bar */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-border px-4 py-3 text-xs text-text-secondary">
            <div>
              Showing {((page - 1) * 30) + 1}–{Math.min(page * 30, total)} of {total} entries
            </div>
            <div className="flex items-center gap-2">
              <Button
                size="sm"
                variant="secondary"
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                leftIcon={<ChevronLeft className="h-3.5 w-3.5" />}
              >
                Previous
              </Button>
              <span className="font-medium text-text-primary px-2">
                {page} / {totalPages}
              </span>
              <Button
                size="sm"
                variant="secondary"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                rightIcon={<ChevronRight className="h-3.5 w-3.5" />}
              >
                Next
              </Button>
            </div>
          </div>
        )}
      </Card>
    </div>
  )
}

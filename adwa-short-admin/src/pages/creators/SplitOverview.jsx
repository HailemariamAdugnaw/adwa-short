import { useNavigate } from 'react-router-dom'
import { Scissors, ArrowUpRight } from 'lucide-react'
import { useCreators } from '../../lib/hooks'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
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
import { formatPercent, initials } from '../../lib/format'

export function SplitOverview() {
  const navigate = useNavigate()
  const { data, isLoading } = useCreators()
  const items = Array.isArray(data) ? data : []

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-text-primary">Split Configuration</h2>
        <p className="text-sm text-text-secondary">
          Pick a creator to configure their revenue split and per-series / per-episode overrides.
        </p>
      </div>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Creator</TH>
              <TH className="text-right">Default Split</TH>
              <TH className="text-right">Platform</TH>
              <TH className="text-right">Overrides</TH>
              <TH className="text-right">Action</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={5} rows={6} />
            ) : items.length === 0 ? (
              <EmptyRow colSpan={5}>
                <EmptyState
                  icon={Scissors}
                  title="No creators yet"
                  description="Add a creator first, then configure their revenue split."
                />
              </EmptyRow>
            ) : (
              items.map((c) => {
                const overrides = Array.isArray(c.split_rules) ? c.split_rules.length : 0
                const creatorPct = c.default_revenue_split_pct ?? 0
                return (
                  <TR
                    key={c.id}
                    className="cursor-pointer"
                    onClick={() => navigate(`/creators/${c.id}/split`)}
                  >
                    <TD>
                      <div className="flex items-center gap-3">
                        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-accent-soft text-accent">
                          {c.avatar_url ? (
                            <img
                              src={c.avatar_url}
                              alt=""
                              className="h-full w-full rounded-full object-cover"
                            />
                          ) : (
                            <span className="text-[10px] font-bold">
                              {initials(c.name, c.phone)}
                            </span>
                          )}
                        </div>
                        <div>
                          <p className="font-medium">{c.name}</p>
                          <p className="text-[10px] text-text-muted">{c.phone ?? '—'}</p>
                        </div>
                      </div>
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-success">
                      {formatPercent(creatorPct, 0)}
                    </TD>
                    <TD className="text-right tabular-nums text-text-secondary">
                      {formatPercent(100 - creatorPct, 0)}
                    </TD>
                    <TD className="text-right">
                      {overrides > 0 ? (
                        <Badge tone="accent">{overrides} rule(s)</Badge>
                      ) : (
                        <Badge tone="neutral">none</Badge>
                      )}
                    </TD>
                    <TD className="text-right">
                      <Button
                        variant="ghost"
                        size="sm"
                        rightIcon={<ArrowUpRight className="h-3.5 w-3.5" />}
                      >
                        Configure
                      </Button>
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </Card>
    </div>
  )
}

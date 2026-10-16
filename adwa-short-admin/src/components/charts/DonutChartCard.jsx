import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { Card, CardHeader, CardTitle } from '../ui/Card'
import { cn } from '../../lib/cn'

const DEFAULT_COLORS = ['#C8102E', '#10B981', '#F59E0B', '#A3A3A3', '#DC2626', '#3A3A3A']

export function DonutChartCard({
  title,
  data,
  height = 280,
  valueFormatter = (v) => String(v),
  loading,
  action,
  centerLabel,
  centerValue,
  className,
}) {
  const dataArr = Array.isArray(data) ? data : []
  const total = dataArr.reduce((sum, d) => sum + (d.value || 0), 0)
  return (
    <Card padding="md" className={cn('overflow-hidden', className)}>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {action}
      </CardHeader>
      <div className="flex items-center gap-6">
        <div className="relative" style={{ width: height, height }}>
          {loading ? (
            <div className="skeleton h-full w-full rounded-full" />
          ) : (
            <>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={dataArr}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="50%"
                    innerRadius="62%"
                    outerRadius="92%"
                    paddingAngle={2}
                    stroke="#0A0A0A"
                    strokeWidth={2}
                  >
                    {dataArr.map((d, i) => (
                      <Cell key={i} fill={d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      background: '#141414',
                      border: '1px solid #2A2A2A',
                      borderRadius: 8,
                      fontSize: 12,
                      color: '#FFFFFF',
                    }}
                    formatter={(value, name) => [valueFormatter(Number(value)), name]}
                  />
                </PieChart>
              </ResponsiveContainer>
              {(centerLabel || centerValue) && (
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  {centerValue && (
                    <span className="text-xl font-bold text-text-primary">{centerValue}</span>
                  )}
                  {centerLabel && (
                    <span className="text-[10px] uppercase tracking-wider text-text-muted">
                      {centerLabel}
                    </span>
                  )}
                </div>
              )}
            </>
          )}
        </div>

        <div className="flex-1 space-y-2">
          {dataArr.map((d, i) => (
            <div key={`${d.name}-${i}`} className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <span
                  className="h-2.5 w-2.5 rounded-sm"
                  style={{ background: d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length] }}
                />
                <span className="text-xs text-text-secondary">{d.name}</span>
              </div>
              <div className="text-right">
                <span className="text-xs font-semibold text-text-primary">
                  {valueFormatter(d.value)}
                </span>
                <span className="ml-1.5 text-[10px] text-text-muted">
                  {total > 0 ? `${((d.value / total) * 100).toFixed(0)}%` : '0%'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </Card>
  )
}

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { Card, CardHeader, CardTitle } from '../ui/Card'
import { cn } from '../../lib/cn'

const DEFAULT_COLORS = ['#C8102E', '#10B981', '#F59E0B', '#A3A3A3', '#DC2626', '#3A3A3A']

export function DonutChartCard({
  title,
  data,
  height = 240,
  valueFormatter = (v) => String(v),
  loading,
  action,
  centerLabel,
  centerValue,
  className,
}) {
  const dataArr = Array.isArray(data) ? data : []
  const total = dataArr.reduce((sum, d) => sum + (Number(d.value) || 0), 0)
  const chartData = total > 0 ? dataArr : [{ name: 'No Data', value: 1, color: '#262626' }]

  return (
    <Card padding="md" className={cn('overflow-hidden flex flex-col justify-between', className)}>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {action}
      </CardHeader>

      <div className="flex flex-col md:flex-row lg:flex-col 2xl:flex-row items-center justify-between gap-5 sm:gap-6 pt-1">
        {/* Scalable Responsive Circle Chart */}
        <div
          className="relative mx-auto w-full aspect-square max-w-[200px] sm:max-w-[220px] shrink-0"
          style={{ height: 'auto', minHeight: 180, maxHeight: height }}
        >
          {loading ? (
            <div className="skeleton h-full w-full rounded-full" />
          ) : (
            <>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={chartData}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="50%"
                    innerRadius="65%"
                    outerRadius="92%"
                    paddingAngle={total > 0 ? 2 : 0}
                    stroke="#0A0A0A"
                    strokeWidth={2}
                  >
                    {chartData.map((d, i) => (
                      <Cell
                        key={i}
                        fill={d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length]}
                      />
                    ))}
                  </Pie>
                  {total > 0 && (
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
                  )}
                </PieChart>
              </ResponsiveContainer>

              {(centerLabel || centerValue) && (
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center px-2">
                  {centerValue && (
                    <span className="text-lg sm:text-xl font-extrabold text-text-primary tracking-tight truncate max-w-[140px]">
                      {centerValue}
                    </span>
                  )}
                  {centerLabel && (
                    <span className="text-[10px] font-bold uppercase tracking-wider text-text-muted mt-0.5 truncate max-w-[140px]">
                      {centerLabel}
                    </span>
                  )}
                </div>
              )}
            </>
          )}
        </div>

        {/* Responsive Legends List */}
        <div className="w-full flex-1 space-y-2 min-w-0">
          {dataArr.map((d, i) => {
            const val = Number(d.value) || 0
            const pct = total > 0 ? ((val / total) * 100).toFixed(0) : '0'
            return (
              <div
                key={`${d.name}-${i}`}
                className="flex items-center justify-between gap-2.5 text-xs py-0.5 border-b border-border/20 last:border-none"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <span
                    className="h-2.5 w-2.5 shrink-0 rounded-sm"
                    style={{ background: d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length] }}
                  />
                  <span className="truncate text-text-secondary font-medium">
                    {d.name}
                  </span>
                </div>
                <div className="text-right shrink-0 flex items-center gap-1.5 tabular-nums">
                  <span className="font-semibold text-text-primary">
                    {valueFormatter(val)}
                  </span>
                  <span className="text-[10px] text-text-muted">
                    ({pct}%)
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </Card>
  )
}

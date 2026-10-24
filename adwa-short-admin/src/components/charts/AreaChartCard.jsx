import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Card, CardHeader, CardTitle } from '../ui/Card'
import { cn } from '../../lib/cn'

const DEFAULT_COLORS = ['#C8102E', '#10B981', '#F59E0B', '#A3A3A3']

export function AreaChartCard({
  title,
  data,
  xKey,
  series,
  height = 280,
  valueFormatter = (v) => String(v),
  loading,
  action,
  className,
}) {
  const dataArr = Array.isArray(data) ? data : []
  const seriesArr = Array.isArray(series) ? series : []
  return (
    <Card padding="md" className={cn('overflow-hidden', className)}>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {action}
      </CardHeader>
      <div style={{ height }} className="w-full">
        {loading ? (
          <div className="skeleton h-full w-full rounded-md" />
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={dataArr} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
              <defs>
                {seriesArr.map((s, i) => {
                  const color = s.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length]
                  return (
                    <linearGradient key={s.key} id={`area-${s.key}`} x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={color} stopOpacity={0.35} />
                      <stop offset="95%" stopColor={color} stopOpacity={0} />
                    </linearGradient>
                  )
                })}
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#2A2A2A" vertical={false} />
              <XAxis
                dataKey={xKey}
                tick={{ fill: '#A3A3A3', fontSize: 11 }}
                axisLine={{ stroke: '#2A2A2A' }}
                tickLine={false}
              />
              <YAxis
                tick={{ fill: '#A3A3A3', fontSize: 11 }}
                axisLine={false}
                tickLine={false}
                tickFormatter={(v) => valueFormatter(Number(v))}
                width={48}
              />
              <Tooltip
                contentStyle={{
                  background: '#141414',
                  border: '1px solid #2A2A2A',
                  borderRadius: 8,
                  fontSize: 12,
                  color: '#FFFFFF',
                }}
                labelStyle={{ color: '#A3A3A3', marginBottom: 4 }}
                formatter={(value, name) => [valueFormatter(Number(value)), name]}
              />
              {seriesArr.map((s, i) => {
                const color = s.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length]
                return (
                  <Area
                    key={s.key}
                    type="monotone"
                    dataKey={s.key}
                    name={s.label}
                    stroke={color}
                    strokeWidth={2}
                    fill={`url(#area-${s.key})`}
                    dot={false}
                    activeDot={{ r: 4, fill: color, stroke: '#0A0A0A', strokeWidth: 2 }}
                  />
                )
              })}
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
      {seriesArr.length > 1 && (
        <div className="mt-3 flex flex-wrap items-center gap-4">
          {seriesArr.map((s, i) => (
            <div key={s.key} className="flex items-center gap-1.5">
              <span
                className="h-2 w-2 rounded-full"
                style={{ background: s.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length] }}
              />
              <span className="text-[11px] text-text-secondary">{s.label}</span>
            </div>
          ))}
        </div>
      )}
    </Card>
  )
}

import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Card, CardHeader, CardTitle } from '../ui/Card'
import { cn } from '../../lib/cn'

const DEFAULT_COLORS = ['#C8102E', '#10B981', '#F59E0B', '#A3A3A3']

export function BarChartCard({
  title,
  data,
  xKey,
  bars,
  height = 300,
  horizontal,
  valueFormatter = (v) => String(v),
  loading,
  action,
  className,
}) {
  const dataArr = Array.isArray(data) ? data : []
  const barsArr = Array.isArray(bars) ? bars : []
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
            <BarChart
              data={dataArr}
              layout={horizontal ? 'vertical' : 'horizontal'}
              margin={{ top: 8, right: 16, left: 0, bottom: 0 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#2A2A2A" vertical={!horizontal} horizontal={horizontal} />
              {horizontal ? (
                <>
                  <XAxis
                    type="number"
                    tick={{ fill: '#A3A3A3', fontSize: 11 }}
                    axisLine={{ stroke: '#2A2A2A' }}
                    tickLine={false}
                    tickFormatter={(v) => valueFormatter(Number(v))}
                  />
                  <YAxis
                    type="category"
                    dataKey={xKey}
                    tick={{ fill: '#A3A3A3', fontSize: 11 }}
                    axisLine={false}
                    tickLine={false}
                    width={120}
                  />
                </>
              ) : (
                <>
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
                </>
              )}
              <Tooltip
                cursor={{ fill: 'rgba(255,255,255,0.04)' }}
                contentStyle={{
                  background: '#141414',
                  border: '1px solid #2A2A2A',
                  borderRadius: 8,
                  fontSize: 12,
                  color: '#FFFFFF',
                }}
                formatter={(value, name) => [valueFormatter(Number(value)), name]}
              />
              {barsArr.map((b, i) => {
                const color = b.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length]
                return (
                  <Bar key={b.key} dataKey={b.key} name={b.label} radius={[4, 4, 0, 0]}>
                    {dataArr.map((_, idx) => (
                      <Cell key={idx} fill={color} />
                    ))}
                  </Bar>
                )
              })}
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>
    </Card>
  )
}

import { useState, useMemo } from 'react'
import {
  Film,
  ListVideo,
  Search,
  Star,
  Coins,
  Clock,
  CreditCard,
  Tv,
  ArrowUpDown,
  Sparkles,
} from 'lucide-react'
import { useCreatorPortalContent } from '../../lib/hooks'
import { formatBirr, formatNumber } from '../../lib/format'
import { Badge } from '../../components/ui/Badge'
import { Input } from '../../components/ui/Input'

export function CreatorContent() {
  const [filterType, setFilterType] = useState('all') // 'all' | 'series' | 'episodes'
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState('views') // 'views' | 'revenue' | 'rating'

  const { data: rawItems, isLoading, error } = useCreatorPortalContent({
    filter_type: filterType,
    q: search.trim() || undefined,
  })

  const sortedItems = useMemo(() => {
    if (!rawItems) return []
    const list = [...rawItems]
    if (sortBy === 'revenue') {
      list.sort((a, b) => b.total_revenue_birr - a.total_revenue_birr)
    } else if (sortBy === 'rating') {
      list.sort((a, b) => b.average_rating - a.average_rating)
    } else {
      list.sort((a, b) => b.total_views - a.total_views)
    }
    return list
  }, [rawItems, sortBy])

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-text-primary">My Content & Performance Breakdown</h1>
          <p className="mt-1 text-xs text-text-secondary">
            Granular watch metrics, monetization splits, and ratings for your published series and episodes.
          </p>
        </div>

        {/* View Type Toggle */}
        <div className="inline-flex rounded-lg border border-border bg-surface-1 p-1">
          <button
            onClick={() => setFilterType('all')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              filterType === 'all'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            All Content
          </button>
          <button
            onClick={() => setFilterType('series')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              filterType === 'series'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            Series Only
          </button>
          <button
            onClick={() => setFilterType('episodes')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              filterType === 'episodes'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            Episodes Only
          </button>
        </div>
      </div>

      {/* Filter & Sort Bar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="w-full sm:max-w-md">
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by title or series name…"
            leftIcon={<Search className="h-4 w-4" />}
          />
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs text-text-muted">Sort By:</span>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="rounded-lg border border-border bg-surface-1 px-3 py-1.5 text-xs font-medium text-text-primary focus:border-accent focus:outline-none"
          >
            <option value="views">Total Qualified Views</option>
            <option value="revenue">Total Credited Revenue</option>
            <option value="rating">Audience Rating</option>
          </select>
        </div>
      </div>

      {/* Breakdown Notice Banner */}
      <div className="rounded-lg border border-border bg-surface-1/60 p-3.5 text-xs text-text-secondary flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-amber-400 shrink-0" />
          <span>
            <strong className="text-text-primary">1-Minute Watch Rule:</strong> Views qualify only when viewers watch for at least 60 seconds. Ad views retain 100% platform share (0 Birr creator credit).
          </span>
        </div>
      </div>

      {/* Content Breakdown Table */}
      <div className="card-surface overflow-hidden">
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
          </div>
        ) : error ? (
          <div className="p-8 text-center text-xs text-accent">
            Failed to load content breakdown.
          </div>
        ) : sortedItems.length === 0 ? (
          <div className="p-12 text-center text-xs text-text-muted">
            <Film className="mx-auto h-8 w-8 text-text-muted mb-2" />
            <p className="font-semibold text-text-primary">No content found</p>
            <p className="mt-1">No series or episodes match your current search or filter.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-border bg-surface-2/60 text-[10px] font-semibold uppercase tracking-wider text-text-muted">
                <tr>
                  <th className="px-4 py-3.5">Content Item</th>
                  <th className="px-3 py-3.5">Type</th>
                  <th className="px-3 py-3.5">Coin Views / Rev</th>
                  <th className="px-3 py-3.5">Pass Views / Rev</th>
                  <th className="px-3 py-3.5">Sub Views / Rev</th>
                  <th className="px-3 py-3.5">Ad Views (0 Birr)</th>
                  <th className="px-3 py-3.5 text-center">Qualified Views</th>
                  <th className="px-3 py-3.5 text-right font-bold text-emerald-400">Net Revenue</th>
                  <th className="px-4 py-3.5 text-center">Rating</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {sortedItems.map((item) => (
                  <tr key={`${item.is_series ? 's' : 'e'}-${item.id}`} className="hover:bg-surface-2/30 transition-colors">
                    {/* Content Item */}
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-surface-2 border border-border text-accent">
                          {item.is_series ? <Film className="h-4 w-4" /> : <ListVideo className="h-4 w-4" />}
                        </div>
                        <div className="min-w-0">
                          <p className="font-bold text-text-primary truncate max-w-[220px]">
                            {item.title}
                          </p>
                          {!item.is_series && (
                            <p className="text-[10px] text-text-muted truncate max-w-[220px]">
                              {item.series_title} · Ep #{item.episode_number}
                            </p>
                          )}
                          {item.is_series && (
                            <p className="text-[10px] text-text-muted">
                              {item.episodes_count} episode{item.episodes_count === 1 ? '' : 's'}
                            </p>
                          )}
                        </div>
                      </div>
                    </td>

                    {/* Type Badge */}
                    <td className="px-3 py-3.5">
                      <Badge tone={item.is_series ? 'accent' : 'neutral'}>
                        {item.is_series ? 'Series' : 'Episode'}
                      </Badge>
                    </td>

                    {/* Coins */}
                    <td className="px-3 py-3.5">
                      <div>
                        <span className="font-semibold text-text-primary">{formatNumber(item.coin_views)}</span>
                        <p className="text-[10px] text-emerald-400 font-mono">
                          +{formatBirr(item.revenue_coins_birr)}
                        </p>
                      </div>
                    </td>

                    {/* Time Pass */}
                    <td className="px-3 py-3.5">
                      <div>
                        <span className="font-semibold text-text-primary">{formatNumber(item.pass_views)}</span>
                        <p className="text-[10px] text-emerald-400 font-mono">
                          +{formatBirr(item.revenue_pass_birr)}
                        </p>
                      </div>
                    </td>

                    {/* Subscription */}
                    <td className="px-3 py-3.5">
                      <div>
                        <span className="font-semibold text-text-primary">{formatNumber(item.subscription_views)}</span>
                        <p className="text-[10px] text-emerald-400 font-mono">
                          +{formatBirr(item.revenue_sub_birr)}
                        </p>
                      </div>
                    </td>

                    {/* Ad-Unlocked */}
                    <td className="px-3 py-3.5">
                      <div>
                        <span className="font-semibold text-text-primary">{formatNumber(item.ad_views)}</span>
                        <p className="text-[10px] text-text-muted font-mono">
                          0.00 Birr
                        </p>
                      </div>
                    </td>

                    {/* Total Qualified Views */}
                    <td className="px-3 py-3.5 text-center font-bold text-text-primary">
                      {formatNumber(item.total_views)}
                    </td>

                    {/* Net Credited Revenue */}
                    <td className="px-3 py-3.5 text-right font-black text-emerald-400 text-sm font-mono">
                      {formatBirr(item.total_revenue_birr)}
                    </td>

                    {/* Rating */}
                    <td className="px-4 py-3.5 text-center">
                      <div className="inline-flex items-center gap-1 font-bold text-amber-400">
                        <Star className="h-3.5 w-3.5 fill-amber-400" />
                        <span>{item.average_rating > 0 ? item.average_rating.toFixed(1) : '–'}</span>
                        <span className="text-[10px] text-text-muted font-normal">
                          ({item.rating_count})
                        </span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}

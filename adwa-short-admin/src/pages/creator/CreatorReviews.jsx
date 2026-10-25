import { useState } from 'react'
import {
  MessageSquare,
  Star,
  Film,
  User,
  Clock,
  Sparkles,
} from 'lucide-react'
import { useCreatorPortalReviews, useCreatorPortalContent } from '../../lib/hooks'
import { Badge } from '../../components/ui/Badge'

export function CreatorReviews() {
  const [selectedSeriesId, setSelectedSeriesId] = useState('')

  // Fetch creator's series list for filtering
  const { data: contentItems } = useCreatorPortalContent({ filter_type: 'series' })
  const seriesOptions = contentItems?.filter((c) => c.is_series) || []

  const { data: reviewsData, isLoading, error } = useCreatorPortalReviews({
    series_id: selectedSeriesId ? Number(selectedSeriesId) : undefined,
  })

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-text-primary">Audience Reviews & Community Ratings</h1>
          <p className="mt-1 text-xs text-text-secondary">
            Verified feedback, episode reviews, and ratings submitted by ADWA SHORT viewers.
          </p>
        </div>

        {/* Series Filter Dropdown */}
        <div className="flex items-center gap-2">
          <span className="text-xs text-text-muted">Filter by Series:</span>
          <select
            value={selectedSeriesId}
            onChange={(e) => setSelectedSeriesId(e.target.value)}
            className="rounded-lg border border-border bg-surface-1 px-3 py-1.5 text-xs font-medium text-text-primary focus:border-accent focus:outline-none"
          >
            <option value="">All Series</option>
            {seriesOptions.map((s) => (
              <option key={s.id} value={s.id}>
                {s.title}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Aggregate Score Card */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="card-surface p-5 flex items-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-amber-500/10 text-amber-400 border border-amber-500/20">
            <Star className="h-7 w-7 fill-amber-400" />
          </div>
          <div>
            <p className="text-xs text-text-muted font-medium">Average Rating</p>
            <p className="text-2xl font-black text-text-primary">
              {reviewsData?.average_rating > 0 ? reviewsData.average_rating.toFixed(1) : '–'}{' '}
              <span className="text-sm font-normal text-text-muted">/ 5.0</span>
            </p>
          </div>
        </div>

        <div className="card-surface p-5 flex items-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-blue-500/10 text-blue-400 border border-blue-500/20">
            <Sparkles className="h-7 w-7" />
          </div>
          <div>
            <p className="text-xs text-text-muted font-medium">Total Star Ratings</p>
            <p className="text-2xl font-black text-text-primary">
              {reviewsData?.total_ratings || 0}
            </p>
          </div>
        </div>

        <div className="card-surface p-5 flex items-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-purple-500/10 text-purple-400 border border-purple-500/20">
            <MessageSquare className="h-7 w-7" />
          </div>
          <div>
            <p className="text-xs text-text-muted font-medium">Written Reviews</p>
            <p className="text-2xl font-black text-text-primary">
              {reviewsData?.total_reviews || 0}
            </p>
          </div>
        </div>
      </div>

      {/* Reviews List */}
      <div className="card-surface p-6">
        <div className="mb-4 flex items-center justify-between border-b border-border pb-3">
          <h2 className="text-sm font-bold text-text-primary">Viewer Feedback Feed</h2>
          <span className="text-xs text-text-muted">
            {reviewsData?.items?.length || 0} recent reviews
          </span>
        </div>

        {isLoading ? (
          <div className="flex h-48 items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
          </div>
        ) : error ? (
          <div className="p-8 text-center text-xs text-accent">
            Failed to load audience reviews.
          </div>
        ) : !reviewsData?.items || reviewsData.items.length === 0 ? (
          <div className="flex h-48 flex-col items-center justify-center rounded-lg border border-dashed border-border text-center text-xs text-text-muted">
            <MessageSquare className="mx-auto h-8 w-8 text-text-muted mb-2" />
            <p className="font-semibold text-text-primary">No reviews found</p>
            <p className="mt-1">Audience comments on your episodes will appear here.</p>
          </div>
        ) : (
          <div className="space-y-3.5">
            {reviewsData.items.map((rev) => (
              <div
                key={rev.id}
                className="rounded-lg border border-border bg-surface-2/40 p-4 transition-colors hover:border-border/80"
              >
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex items-center gap-2.5">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-3 text-xs font-bold text-text-secondary border border-border">
                      {(rev.user_display_name || 'V')[0].toUpperCase()}
                    </div>
                    <div>
                      <p className="text-xs font-bold text-text-primary">
                        {rev.user_display_name}
                      </p>
                      <p className="text-[10px] text-text-muted">
                        {rev.series_title} · {rev.episode_title} (Ep #{rev.episode_number})
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {rev.rating !== null && rev.rating !== undefined && (
                      <div className="flex items-center gap-1 text-xs font-bold text-amber-400">
                        <Star className="h-3.5 w-3.5 fill-amber-400" />
                        <span>{rev.rating} / 5</span>
                      </div>
                    )}
                    <span className="text-[10px] text-text-muted">
                      {rev.created_at ? new Date(rev.created_at).toLocaleDateString() : 'N/A'}
                    </span>
                  </div>
                </div>

                <p className="mt-3 text-xs leading-relaxed text-text-secondary bg-surface-1/60 rounded-md p-3 border border-border/40">
                  “{rev.text}”
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

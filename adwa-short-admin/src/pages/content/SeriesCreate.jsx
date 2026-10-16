import { Link } from 'react-router-dom'
import { ChevronLeft } from 'lucide-react'
import { SeriesForm } from '../../components/content/SeriesForm'

export function SeriesCreate() {
  return (
    <div className="space-y-4">
      <div>
        <Link
          to="/content/series"
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to Series
        </Link>
        <h2 className="mt-1 text-xl font-bold text-text-primary">Create New Series</h2>
        <p className="text-sm text-text-secondary">
          Fill in the details below to add a new series or short to the catalog.
        </p>
      </div>
      <SeriesForm />
    </div>
  )
}

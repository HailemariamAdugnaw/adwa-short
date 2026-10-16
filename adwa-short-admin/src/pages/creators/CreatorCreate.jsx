import { useNavigate, Link } from 'react-router-dom'
import { ChevronLeft } from 'lucide-react'
import { CreatorForm } from '../../components/content/CreatorForm'
import { Card } from '../../components/ui/Card'

export function CreatorCreate() {
  const navigate = useNavigate()
  return (
    <div className="space-y-4">
      <div>
        <Link
          to="/creators"
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to Creators
        </Link>
      </div>
      <div>
        <h2 className="text-xl font-bold text-text-primary">Add Creator</h2>
        <p className="text-sm text-text-secondary">
          Register a content creator with bank details, contract, and default revenue split.
        </p>
      </div>
      <Card padding="lg">
        <CreatorForm onSaved={(saved) => navigate(`/creators/${saved?.id ?? ''}`)} />
      </Card>
    </div>
  )
}

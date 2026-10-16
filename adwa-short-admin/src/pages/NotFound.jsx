import { Link } from 'react-router-dom'
import { Home } from 'lucide-react'
import { Button } from '../components/ui/Button'

export function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-base px-6 text-center">
      <p className="text-[120px] font-extrabold leading-none text-accent">404</p>
      <p className="mt-2 text-sm uppercase tracking-widest text-text-muted">Page not found</p>
      <p className="mt-4 max-w-md text-sm text-text-secondary">
        The page you are looking for doesn't exist or has been moved. Return to the dashboard to
        continue.
      </p>
      <Link to="/" className="mt-6">
        <Button leftIcon={<Home className="h-4 w-4" />}>Back to Dashboard</Button>
      </Link>
    </div>
  )
}

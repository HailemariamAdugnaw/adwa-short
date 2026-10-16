import { Toaster } from 'react-hot-toast'

export function ToastProvider() {
  return (
    <Toaster
      position="top-right"
      toastOptions={{
        duration: 3500,
        style: {
          background: '#141414',
          color: '#FFFFFF',
          border: '1px solid #2A2A2A',
          fontSize: '13px',
          borderRadius: '8px',
          padding: '10px 14px',
          boxShadow: '0 8px 30px -8px rgba(0,0,0,0.6)',
        },
        success: {
          iconTheme: { primary: '#10B981', secondary: '#FFFFFF' },
          style: { border: '1px solid rgba(16,185,129,0.4)' },
        },
        error: {
          iconTheme: { primary: '#C8102E', secondary: '#FFFFFF' },
          style: { border: '1px solid rgba(200,16,46,0.4)' },
        },
        loading: { iconTheme: { primary: '#C8102E', secondary: '#FFFFFF' } },
      }}
    />
  )
}

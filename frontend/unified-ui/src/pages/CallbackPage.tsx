import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { completeOidcCallback } from '../auth/oidc'

/**
 * OIDC redirect target — /auth/callback?code=&state=
 */
export function CallbackPage() {
  const nav = useNavigate()
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        await completeOidcCallback(window.location.search)
        if (!cancelled) nav('/', { replace: true })
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e))
      }
    })()
    return () => {
      cancelled = true
    }
  }, [nav])

  return (
    <div className="shell">
      <header className="header">
        <div>
          <h1>ArchGate</h1>
          <div className="brand">UnifiedUI · OIDC callback</div>
        </div>
      </header>
      <div className="card">
        {error ? (
          <>
            <h2>Falha no login</h2>
            <p className="muted">{error}</p>
            <button type="button" className="btn" onClick={() => nav('/', { replace: true })}>
              Voltar
            </button>
          </>
        ) : (
          <>
            <h2>Autenticando…</h2>
            <p className="muted">Trocando código OIDC (PKCE).</p>
          </>
        )}
      </div>
    </div>
  )
}

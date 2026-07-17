import { useEffect, useState } from 'react'
import { ConnectionCatalog } from '../components/ConnectionCatalog'
import { SessionPanel } from '../components/SessionPanel'
import { fetchMyConnections } from '../api/catalog'
import { beginOidcLogin, isOidcEnabled, logoutOidc } from '../auth/oidc'
import { clearSession, getSession, setMockSession, type UserSession } from '../auth/session'
import type { Connection } from '../types'

export function HomePage() {
  const [session, setSession] = useState<UserSession | null>(() => getSession())
  const [selected, setSelected] = useState<Connection | null>(null)
  const [connections, setConnections] = useState<Connection[]>([])
  const [catalogSource, setCatalogSource] = useState<'bff' | 'mock' | null>(null)
  const [loadingCatalog, setLoadingCatalog] = useState(false)
  const [oidcBusy, setOidcBusy] = useState(false)

  useEffect(() => {
    if (!session) {
      setConnections([])
      setCatalogSource(null)
      return
    }
    let cancelled = false
    setLoadingCatalog(true)
    void fetchMyConnections(session).then((r) => {
      if (cancelled) return
      setConnections(r.connections)
      setCatalogSource(r.source)
      setLoadingCatalog(false)
    })
    return () => {
      cancelled = true
    }
  }, [session])

  if (!session) {
    return (
      <div className="shell">
        <header className="header">
          <div>
            <h1>ArchGate</h1>
            <div className="brand">UnifiedUI · operador</div>
          </div>
        </header>
        <div className="card">
          <h2>Entrar</h2>
          <p className="muted">
            Produção: OIDC Kanidm (Code+PKCE) com client{' '}
            <code>archgate-unified-ui</code>. Lab: sessão mock (
            <code>uat-op-a</code> / Rio).
          </p>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            <button
              type="button"
              className="btn"
              onClick={() => setSession(setMockSession())}
            >
              Entrar como operador lab (mock)
            </button>
            <button
              type="button"
              className="btn"
              disabled={oidcBusy || !isOidcEnabled()}
              title={
                isOidcEnabled()
                  ? 'Redirect Kanidm'
                  : 'Defina VITE_OIDC_ENABLED=1 e registre o client no Kanidm'
              }
              onClick={() => {
                setOidcBusy(true)
                void beginOidcLogin().catch((e) => {
                  setOidcBusy(false)
                  alert(e instanceof Error ? e.message : String(e))
                })
              }}
            >
              {oidcBusy ? 'Redirecionando…' : 'Entrar com SSO (OIDC)'}
            </button>
          </div>
          {!isOidcEnabled() && (
            <p className="muted" style={{ marginBottom: 0, marginTop: '0.75rem', fontSize: '0.8rem' }}>
              SSO desligado no build. Habilite com{' '}
              <code>VITE_OIDC_ENABLED=1</code> + issuer/client em{' '}
              <code>.env</code> (ver README).
            </p>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="shell">
      <header className="header">
        <div>
          <h1>ArchGate</h1>
          <div className="brand">
            {session.displayName} · {session.tenants.join(', ')} · {session.mode}
            {catalogSource ? ` · catálogo ${catalogSource}` : ''}
          </div>
        </div>
        <button
          type="button"
          className="btn"
          onClick={() => {
            logoutOidc()
            clearSession()
            setSession(null)
            setSelected(null)
          }}
        >
          Sair
        </button>
      </header>

      <div className="grid-2">
        {loadingCatalog ? (
          <div className="card">
            <h2>Minhas conexões</h2>
            <p className="muted">Carregando…</p>
          </div>
        ) : (
          <ConnectionCatalog
            connections={connections}
            selectedId={selected?.id ?? null}
            onSelect={setSelected}
          />
        )}
        <SessionPanel
          connection={selected}
          username={session.username ?? session.email.split('@')[0]}
        />
      </div>

      <div className="card">
        <h2>Próximos passos (W4)</h2>
        <ul className="muted" style={{ margin: 0, paddingLeft: '1.2rem' }}>
          <li>Registrar OIDC client no Kanidm e BFF cookie session</li>
          <li>API catálogo real + <code>POST /sessions</code> tunnel token</li>
          <li>Adapters live de orquestração (Kanidm/WG/Guac/OpenBao)</li>
          <li>E2E browser smoke (W4-UI09)</li>
        </ul>
      </div>
    </div>
  )
}

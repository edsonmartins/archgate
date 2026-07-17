import { useMemo, useState } from 'react'
import { ConnectionCatalog } from '../components/ConnectionCatalog'
import { SessionPanel } from '../components/SessionPanel'
import { MOCK_CONNECTIONS } from '../data/mockConnections'
import { clearSession, getSession, setMockSession, type UserSession } from '../auth/session'
import type { Connection } from '../types'

export function HomePage() {
  const [session, setSession] = useState<UserSession | null>(() => getSession())
  const [selected, setSelected] = useState<Connection | null>(null)

  const connections = useMemo(() => {
    if (!session) return []
    return MOCK_CONNECTIONS.filter((c) => session.tenants.includes(c.tenant))
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
            OIDC Kanidm (Code+PKCE) entra em W4-UI02. Enquanto isso, use sessão mock de lab
            (equivalente a <code>uat-op-a</code> / Rio).
          </p>
          <button
            type="button"
            className="btn"
            onClick={() => setSession(setMockSession())}
          >
            Entrar como operador lab (mock)
          </button>
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
          </div>
        </div>
        <button
          type="button"
          className="btn"
          onClick={() => {
            clearSession()
            setSession(null)
            setSelected(null)
          }}
        >
          Sair
        </button>
      </header>

      <div className="grid-2">
        <ConnectionCatalog
          connections={connections}
          selectedId={selected?.id ?? null}
          onSelect={setSelected}
        />
        <SessionPanel connection={selected} />
      </div>

      <div className="card">
        <h2>Próximos passos (W4)</h2>
        <ul className="muted" style={{ margin: 0, paddingLeft: '1.2rem' }}>
          <li>OIDC real contra id.archgate.com.br</li>
          <li>API catálogo filtrada por RBAC (BFF)</li>
          <li>guacamole-common-js no painel de sessão</li>
          <li>Snippets Warpgate desktop (SSH/PG) a partir do catálogo</li>
        </ul>
      </div>
    </div>
  )
}

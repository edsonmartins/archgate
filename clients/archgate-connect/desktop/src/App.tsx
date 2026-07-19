import { useCallback, useEffect, useMemo, useState } from 'react'
import { runArchgate, type RunResult } from './archgate'
import {
  IconAlert,
  IconChevron,
  IconGate,
  IconPlug,
  IconSearch,
  IconShield,
} from './icons'
import { protocolMeta, type Connection } from './protocol'

type Status = {
  user?: string
  warpgate_user?: string
  session?: boolean
  auth?: string
  connections?: number
  bastion?: { ssh_host?: string; ssh_port?: number }
}

type Notice = {
  kind: 'ok' | 'info' | 'err'
  text: string
}

function parseJSON<T>(text: string): T | null {
  try {
    return JSON.parse(text) as T
  } catch {
    return null
  }
}

function summarizeLogin(stdout: string, fallbackUser: string): string {
  const line =
    stdout
      .split('\n')
      .map((l) => l.trim())
      .find((l) => l.toLowerCase().includes('logged in') || l.toLowerCase().includes('logado')) ||
    ''
  if (line) return line
  return `Login concluído (${fallbackUser || 'operador'}).`
}

export function App() {
  const [user, setUser] = useState('')
  const [status, setStatus] = useState<Status | null>(null)
  const [log, setLog] = useState('')
  const [showLog, setShowLog] = useState(false)
  const [notice, setNotice] = useState<Notice | null>(null)
  const [conns, setConns] = useState<Connection[]>([])
  const [busyCount, setBusyCount] = useState(0)
  const [pending, setPending] = useState<string | null>(null)
  const [filter, setFilter] = useState('')
  const [bootstrapped, setBootstrapped] = useState(false)

  const busy = busyCount > 0

  const withBusy = useCallback(async <T,>(fn: () => Promise<T>): Promise<T> => {
    setBusyCount((n) => n + 1)
    try {
      return await fn()
    } finally {
      setBusyCount((n) => Math.max(0, n - 1))
    }
  }, [])

  const runLogged = useCallback(
    async (args: string[]): Promise<RunResult> => {
      return withBusy(async () => {
        const r = await runArchgate(args)
        const text = `$ archgate ${args.join(' ')}\n${r.stdout}${r.stderr}`
        setLog(text)
        return r
      })
    },
    [withBusy],
  )

  const refresh = useCallback(async (): Promise<Status | null> => {
    const [st, ls] = await withBusy(async () =>
      Promise.all([
        runArchgate(['status', '--json']),
        runArchgate(['ls', '--json']),
      ]),
    )

    let next: Status | null = null

    if (st.code === 0 && st.stdout) {
      next = parseJSON<Status>(st.stdout)
      if (next) {
        setStatus(next)
        // Prefill catalog field only when empty (don't fight the user typing).
        if (next.user) {
          setUser((prev) => (prev.trim() === '' ? next!.user! : prev))
        }
      }
    } else if (st.code !== 0) {
      setNotice({
        kind: 'err',
        text: st.stderr || st.stdout || `status falhou (exit ${st.code})`,
      })
    }

    if (ls.code === 0 && ls.stdout) {
      const data = parseJSON<{ connections?: Connection[] }>(ls.stdout)
      setConns(data?.connections || [])
    } else {
      setConns([])
      if (ls.code !== 0 && st.code === 0) {
        // Offline / not logged in: ls often fails — don't scream unless we thought we had a session.
        if (next?.session) {
          setNotice({
            kind: 'err',
            text: ls.stderr || ls.stdout || `catálogo falhou (exit ${ls.code})`,
          })
        }
      }
    }

    setBootstrapped(true)
    return next
  }, [withBusy])

  useEffect(() => {
    void refresh()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- mount-only
  }, [])

  const loginLab = async () => {
    const catalogUser = user.trim() || 'lab.operator'
    setPending('lab')
    setNotice({
      kind: 'info',
      text: `Entrando no catálogo lab como “${catalogUser}”…`,
    })
    setShowLog(true)

    try {
      const r = await runLogged(['login', '--lab', '--user', catalogUser])
      if (r.code !== 0) {
        setNotice({
          kind: 'err',
          text: r.stderr || r.stdout || `Login lab falhou (exit ${r.code})`,
        })
        return
      }
      const st = await refresh()
      const n = st?.connections ?? conns.length
      const wg = st?.warpgate_user || '—'
      setNotice({
        kind: 'ok',
        text: `${summarizeLogin(r.stdout, catalogUser)} Warpgate SSH: ${wg}. Conexões: ${n >= 0 ? n : '—'}.`,
      })
    } catch (e) {
      setNotice({ kind: 'err', text: (e as Error).message })
    } finally {
      setPending(null)
    }
  }

  const loginOidc = async () => {
    setPending('sso')
    setNotice({
      kind: 'info',
      text: 'Abrindo login SSO no browser… Conclua no Kanidm e volte aqui (pode levar até alguns minutos).',
    })
    setShowLog(true)

    try {
      const r = await runLogged(['login'])
      if (r.code !== 0) {
        setNotice({
          kind: 'err',
          text: r.stderr || r.stdout || `Login SSO falhou (exit ${r.code})`,
        })
        return
      }
      const st = await refresh()
      const n = st?.connections ?? 0
      const who = st?.user || 'operador'
      const wg = st?.warpgate_user || who
      setNotice({
        kind: 'ok',
        text: `SSO ok — ${who}. Warpgate SSH: ${wg}. Conexões: ${n}.`,
      })
    } catch (e) {
      setNotice({ kind: 'err', text: (e as Error).message })
    } finally {
      setPending(null)
    }
  }

  const logout = async () => {
    setPending('logout')
    setNotice({ kind: 'info', text: 'Encerrando sessão…' })
    try {
      const r = await runLogged(['logout'])
      await refresh()
      if (r.code === 0) {
        setNotice({ kind: 'ok', text: 'Sessão encerrada. Faça login lab ou SSO para continuar.' })
        setUser('')
      } else {
        setNotice({
          kind: 'err',
          text: r.stderr || r.stdout || `Logout falhou (exit ${r.code})`,
        })
      }
    } finally {
      setPending(null)
    }
  }

  const connect = async (c: Connection) => {
    const meta = protocolMeta(c.protocol)
    setPending(`connect:${c.target}`)
    setNotice({ kind: 'info', text: `Abrindo ${meta.actionLabel} · ${c.target}…` })
    setShowLog(true)
    try {
      const r = await runLogged(meta.cliArgs(c))
      if (r.code !== 0) {
        setNotice({
          kind: 'err',
          text: r.stderr || r.stdout || `Falha ao abrir ${c.target}`,
        })
        return
      }
      setNotice({
        kind: 'ok',
        text: `${meta.actionLabel} · ${c.target} — comando enviado (veja o console se precisar da linha SSH).`,
      })
    } finally {
      setPending(null)
    }
  }

  const visible = useMemo(() => {
    if (!filter.trim()) return conns
    const q = filter.toLowerCase()
    return conns.filter(
      (c) =>
        c.target.toLowerCase().includes(q) ||
        c.site.toLowerCase().includes(q) ||
        c.protocol.toLowerCase().includes(q) ||
        (c.tenant || '').toLowerCase().includes(q) ||
        (c.name || '').toLowerCase().includes(q),
    )
  }, [conns, filter])

  const sessionOn = !!status?.session
  const wgUser = status?.warpgate_user || '—'
  const bastionHost = status?.bastion?.ssh_host || '—'
  const bastionPort = status?.bastion?.ssh_port
  const catalogUser = status?.user || '—'
  const authMode = status?.auth || 'none'
  const connCount = status?.connections ?? conns.length

  const pillLabel = !bootstrapped
    ? 'Carregando…'
    : sessionOn
      ? `Ativo · ${catalogUser}`
      : 'Offline'

  return (
    <div className="app">
      <div className={`busy-bar ${busy ? 'on' : ''}`} aria-hidden />

      <header className="topbar">
        <div className="brand">
          <div className="brand-mark" aria-hidden>
            <IconGate />
          </div>
          <div className="brand-text">
            <h1>ArchGate Connect</h1>
            <p className="subtitle">Bastion access · sem VPN no notebook</p>
          </div>
        </div>
        <div
          className={`session-pill ${sessionOn ? 'on' : ''} ${!bootstrapped ? 'loading' : ''}`}
          role="status"
          aria-live="polite"
        >
          <span className="dot" />
          {pillLabel}
        </div>
      </header>

      <main className="main">
        <div className="callout">
          <div className="callout-icon">
            <IconShield />
          </div>
          <div className="callout-body">
            <strong>Bastion, not VPN.</strong> O acesso privilegiado passa pelo
            ArchGate (Warpgate). Forti/OpenVPN ficam no VPS — não no seu Mac.
          </div>
        </div>

        <section className="panel">
          <h3 className="panel-label">Identidade</h3>

          {sessionOn ? (
            <div className="session-summary" role="status">
              <div className="session-summary-row">
                <span className="k">Estado</span>
                <span className="v ok">Logado ({authMode})</span>
              </div>
              <div className="session-summary-row">
                <span className="k">Catálogo</span>
                <span className="v mono">{catalogUser}</span>
              </div>
              <div className="session-summary-row">
                <span className="k">SSH Warpgate</span>
                <span className="v mono accent">
                  {wgUser}
                  <span className="dim">
                    {' '}
                    · {bastionHost}
                    {bastionPort != null ? `:${bastionPort}` : ''}
                  </span>
                </span>
              </div>
              <div className="session-summary-row">
                <span className="k">Conexões</span>
                <span className="v mono">{connCount}</span>
              </div>
            </div>
          ) : (
            <p className="auth-hint">
              Sem sessão. Use <strong>Login lab</strong> (homolog) ou{' '}
              <strong>Login SSO</strong> (Kanidm no browser).
            </p>
          )}

          <div className="auth-row">
            <input
              className="field"
              value={user}
              onChange={(e) => setUser(e.target.value)}
              placeholder="usuário do catálogo lab (ex.: edson)"
              spellCheck={false}
              aria-label="Usuário do catálogo lab"
              autoComplete="username"
              disabled={busy}
            />
            <button
              className="btn btn-ghost"
              disabled={busy}
              onClick={() => void loginLab()}
              aria-busy={pending === 'lab'}
            >
              {pending === 'lab' ? 'Entrando…' : 'Login lab'}
            </button>
            <button
              className="btn btn-primary"
              disabled={busy}
              onClick={() => void loginOidc()}
              aria-busy={pending === 'sso'}
            >
              {pending === 'sso' ? 'Aguardando SSO…' : 'Login SSO'}
            </button>
          </div>
          <div className="tool-row">
            <button
              className="btn btn-ghost btn-sm"
              disabled={busy}
              onClick={() => {
                setNotice({ kind: 'info', text: 'Atualizando status e catálogo…' })
                void refresh().then((st) => {
                  if (st?.session) {
                    setNotice({
                      kind: 'ok',
                      text: `Sessão ativa · ${st.user || '—'} · ${st.connections ?? 0} conexões · WG ${st.warpgate_user || '—'}`,
                    })
                  } else {
                    setNotice({
                      kind: 'info',
                      text: 'Sem sessão ativa. Faça Login lab ou SSO.',
                    })
                  }
                })
              }}
            >
              Atualizar
            </button>
            <button
              className="btn btn-ghost btn-sm"
              disabled={busy || !sessionOn}
              onClick={() => {
                setPending('config')
                setNotice({ kind: 'info', text: 'Aplicando SSH config…' })
                void runLogged(['config', 'apply'])
                  .then((r) => {
                    if (r.code === 0) {
                      setNotice({ kind: 'ok', text: r.stdout.trim() || 'SSH config aplicado.' })
                    } else {
                      setNotice({
                        kind: 'err',
                        text: r.stderr || r.stdout || 'Falha no SSH config',
                      })
                    }
                  })
                  .finally(() => setPending(null))
              }}
            >
              SSH config
            </button>
            <button
              className="btn btn-ghost btn-sm"
              disabled={busy}
              onClick={() => {
                setPending('doctor')
                setShowLog(true)
                setNotice({ kind: 'info', text: 'Rodando doctor…' })
                void runLogged(['doctor', '--json'])
                  .then((r) => {
                    if (r.code === 0) {
                      setNotice({ kind: 'ok', text: 'Doctor concluído — veja o console.' })
                    } else {
                      setNotice({
                        kind: 'err',
                        text: r.stderr || r.stdout || 'Doctor falhou',
                      })
                    }
                  })
                  .finally(() => setPending(null))
              }}
            >
              Doctor
            </button>
            <button
              className="btn btn-ghost btn-sm"
              disabled={busy || !sessionOn}
              onClick={() => void logout()}
            >
              {pending === 'logout' ? 'Saindo…' : 'Logout'}
            </button>
          </div>
        </section>

        {notice ? (
          <div
            className={`alert alert-${notice.kind === 'ok' ? 'ok' : notice.kind === 'info' ? 'info' : 'error'}`}
            role={notice.kind === 'err' ? 'alert' : 'status'}
            aria-live="polite"
          >
            {notice.kind === 'err' ? <IconAlert className="alert-icon" /> : null}
            <span>{notice.text}</span>
            <button
              type="button"
              className="alert-dismiss"
              aria-label="Fechar aviso"
              onClick={() => setNotice(null)}
            >
              ×
            </button>
          </div>
        ) : null}

        <section className="panel panel-grow">
          <div className="panel-head">
            <h2>Conexões</h2>
            <span className="count-badge">
              {visible.length}
              {conns.length !== visible.length ? ` / ${conns.length}` : ''}
            </span>
          </div>

          <div className="search-wrap">
            <IconSearch className="search-icon" />
            <input
              className="field"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              placeholder="Filtrar por target, site, protocolo…"
              spellCheck={false}
              aria-label="Filtrar conexões"
              disabled={!sessionOn && conns.length === 0}
            />
          </div>

          {!bootstrapped ? (
            <div className="empty">
              <div className="empty-glyph pulse">
                <IconPlug />
              </div>
              Carregando sessão…
            </div>
          ) : visible.length === 0 ? (
            <div className="empty">
              <div className="empty-glyph">
                <IconPlug />
              </div>
              {sessionOn
                ? 'Nenhuma conexão neste filtro.'
                : 'Faça login lab ou SSO para carregar o catálogo.'}
              <div className="hint">
                O campo acima é só o <em>nickname do catálogo lab</em>. SSH usa o
                usuário Warpgate <strong>{wgUser}</strong>
                {sessionOn ? '' : ' (definido no login lab, default uat-op-a)'}.
              </div>
            </div>
          ) : (
            <ul className="conn-list">
              {visible.map((c) => {
                const meta = protocolMeta(c.protocol)
                const isConnecting = pending === `connect:${c.target}`
                return (
                  <li className={`conn-item ${meta.protoCls}`} key={c.id || c.target}>
                    <div className={`conn-icon ${meta.iconCls}`} aria-hidden>
                      {meta.badge}
                    </div>
                    <div className="conn-body">
                      <div className="conn-name" title={c.target}>
                        {c.target}
                      </div>
                      <div className="conn-meta">
                        <span className="chip">{c.protocol}</span>
                        <span className="chip">{c.engine}</span>
                        {c.site ? <span className="chip-site">{c.site}</span> : null}
                      </div>
                    </div>
                    <button
                      className={`btn btn-sm btn-action ${meta.actionBtn}`}
                      disabled={busy}
                      onClick={() => void connect(c)}
                      aria-label={`${meta.actionLabel} ${c.target}`}
                    >
                      {isConnecting ? '…' : meta.actionLabel}
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </section>
      </main>

      <div className="log-panel">
        <button
          type="button"
          className="log-toggle"
          onClick={() => setShowLog((v) => !v)}
          aria-expanded={showLog}
        >
          <span>Console / log {log ? '· tem saída' : ''}</span>
          <span className={`log-chevron ${showLog ? 'open' : ''}`}>
            <IconChevron />
          </span>
        </button>
        {showLog ? (
          <pre className="log-body">
            {log || '(vazio — ações de login/SSH aparecem aqui)'}
          </pre>
        ) : null}
      </div>
    </div>
  )
}

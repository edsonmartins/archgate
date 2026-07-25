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
import { FirstRunWizard } from './onboarding/FirstRunWizard'
import { loadAppPrefs, patchAppPrefs, type AppPrefs } from './prefs/appPrefs'
import { TerminalPrefsPanel } from './prefs/TerminalPrefsPanel'
import { protocolMeta, type Connection } from './protocol'
import { SessionWorkspace } from './sessions/SessionWorkspace'
import { newSessionTab, type SessionState, type SessionTab } from './sessions/types'

type Status = {
  user?: string
  warpgate_user?: string
  session?: boolean
  auth?: string
  connections?: number
  token_ok?: boolean
  need_login?: boolean
  token_error?: string
  expires_at?: number
  bastion?: { ssh_host?: string; ssh_port?: number }
}

function looksLikeNeedLogin(text: string): boolean {
  const t = text.toLowerCase()
  return (
    t.includes('session expired') ||
    t.includes('need_login') ||
    t.includes('run: archgate login') ||
    (t.includes('archgate login') && t.includes('expired')) ||
    t.includes('unauthorized') ||
    /\b401\b/.test(t)
  )
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
  const [sessionTabs, setSessionTabs] = useState<SessionTab[]>([])
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null)
  const [prefsOpen, setPrefsOpen] = useState(false)
  const [prefsTarget, setPrefsTarget] = useState<string | null>(null)
  const [appPrefs, setAppPrefs] = useState<AppPrefs>(() => loadAppPrefs())
  const [wgUserEdit, setWgUserEdit] = useState('')
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [actionsOpen, setActionsOpen] = useState(false)
  const [doctorOk, setDoctorOk] = useState<boolean | null>(null)
  const [sessionExpired, setSessionExpired] = useState(false)
  const [showOnboarding, setShowOnboarding] = useState(
    () => !loadAppPrefs().onboardingDone,
  )

  const busy = busyCount > 0
  const homologMode = appPrefs.homologMode
  const showWgTip = !appPrefs.wgPasswordTipDismissed

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
        if (next.warpgate_user) {
          setWgUserEdit((prev) => (prev.trim() === '' ? next!.warpgate_user! : prev))
        }
        if (next.need_login || next.token_ok === false) {
          setSessionExpired(true)
          setNotice({
            kind: 'err',
            text:
              next.token_error ||
              'Sessão SSO expirada. Use Reconectar SSO para renovar.',
          })
          setConns([])
        } else if (next.session) {
          setSessionExpired(false)
        }
      }
    } else if (st.code !== 0) {
      const msg = st.stderr || st.stdout || `status falhou (exit ${st.code})`
      if (looksLikeNeedLogin(msg)) {
        setSessionExpired(true)
        setNotice({
          kind: 'err',
          text: `Sessão expirada — reconecte com SSO.\n${msg}`,
        })
      } else {
        setNotice({ kind: 'err', text: msg })
      }
    }

    if (ls.code === 0 && ls.stdout) {
      const data = parseJSON<{ connections?: Connection[] }>(ls.stdout)
      setConns(data?.connections || [])
    } else {
      setConns([])
      const lsMsg = ls.stderr || ls.stdout || `catálogo falhou (exit ${ls.code})`
      if (ls.code !== 0 && st.code === 0) {
        if (next?.need_login || looksLikeNeedLogin(lsMsg)) {
          setSessionExpired(true)
          setNotice({
            kind: 'err',
            text: `Sessão expirada — reconecte com SSO.\n${lsMsg}`,
          })
        } else if (next?.session) {
          setNotice({
            kind: 'err',
            text: lsMsg,
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

  const closeAllSessions = useCallback(async (reason?: string) => {
    for (const t of sessionTabs) {
      try {
        const { invoke } = await import('@tauri-apps/api/core')
        await invoke('ssh_session_close', { sessionId: t.id })
      } catch {
        /* ignore */
      }
    }
    setSessionTabs([])
    setActiveSessionId(null)
    if (reason) {
      setNotice({ kind: 'info', text: reason })
    }
  }, [sessionTabs])

  const saveWgUser = async () => {
    const name = wgUserEdit.trim()
    if (!name) {
      setNotice({ kind: 'err', text: 'Informe o usuário Warpgate (ex.: uat-op-a).' })
      return
    }
    setPending('wg-user')
    try {
      const r = await runLogged(['wg-user', name])
      if (r.code !== 0) {
        setNotice({ kind: 'err', text: r.stderr || r.stdout || 'Falha ao salvar wg-user' })
        return
      }
      await refresh()
      setNotice({
        kind: 'ok',
        text: `Usuário Warpgate salvo: ${name}. SSH/DB usarão este login no bastion.`,
      })
    } finally {
      setPending(null)
    }
  }

  const runDoctorCheck = async (): Promise<boolean> => {
    setPending('doctor')
    setShowLog(true)
    setNotice({ kind: 'info', text: 'Rodando doctor…' })
    try {
      const r = await runLogged(['doctor', '--json'])
      if (r.code !== 0) {
        setDoctorOk(false)
        setNotice({ kind: 'err', text: r.stderr || r.stdout || 'Doctor falhou' })
        return false
      }
      const data = parseJSON<{ checks?: { ok?: boolean; name?: string }[] }>(r.stdout)
      const fails = (data?.checks || []).filter((c) => c && c.ok === false)
      if (fails.length) {
        setDoctorOk(false)
        setNotice({
          kind: 'err',
          text: `Doctor: falhas em ${fails.map((f) => f.name).join(', ')}`,
        })
        return false
      }
      setDoctorOk(true)
      setNotice({ kind: 'ok', text: 'Doctor OK — bastion e catálogo saudáveis.' })
      return true
    } finally {
      setPending(null)
    }
  }

  const reconnectSso = async () => {
    await closeAllSessions('Sessões embutidas encerradas por reauth.')
    await loginOidc()
  }

  const logout = async () => {
    setPending('logout')
    setNotice({ kind: 'info', text: 'Encerrando sessão…' })
    try {
      const r = await runLogged(['logout'])
      await closeAllSessions()
      setSessionExpired(false)
      await refresh()
      if (r.code === 0) {
        setNotice({ kind: 'ok', text: 'Sessão encerrada. Entre com SSO para continuar.' })
        setUser('')
        setWgUserEdit('')
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

  const finishOnboarding = () => {
    const next = patchAppPrefs({ onboardingDone: true })
    setAppPrefs(next)
    setShowOnboarding(false)
  }

  /** S1: open RDM tab; external launch remains available from the tab. */
  const openSessionTab = (c: Connection) => {
    const existing = sessionTabs.find((t) => t.connection.target === c.target)
    if (existing) {
      setActiveSessionId(existing.id)
      setNotice({ kind: 'info', text: `Aba já aberta: ${c.target}` })
      return
    }
    if (sessionTabs.length >= 8) {
      setNotice({ kind: 'err', text: 'Limite de 8 sessões — feche uma aba antes de abrir outra.' })
      return
    }
    const tab = newSessionTab(c)
    setSessionTabs((prev) => [...prev, tab])
    setActiveSessionId(tab.id)
    setNotice({
      kind: 'ok',
      text:
        tab.kind === 'ssh'
          ? `SSH embutido «${c.target}» — senha Warpgate do operador se pedida.`
          : tab.kind === 'guac'
            ? `RDP/VNC embutido «${c.target}» (Guacamole no app).`
            : tab.kind === 'db'
              ? `DB embutido «${c.target}» — senha Warpgate no psql se pedida.`
              : `Painel embutido «${c.target}».`,
    })
  }

  const updateSessionState = (id: string, state: SessionState, note?: string) => {
    setSessionTabs((prev) =>
      prev.map((t) =>
        t.id === id
          ? {
              ...t,
              state,
              note: note ?? t.note,
            }
          : t,
      ),
    )
  }

  const closeSessionTab = (id: string) => {
    // SshTerminal cleanup closes PTY on unmount; also best-effort kill from here.
    void (async () => {
      try {
        const { invoke } = await import('@tauri-apps/api/core')
        await invoke('ssh_session_close', { sessionId: id })
      } catch {
        /* not open or not tauri */
      }
    })()
    setSessionTabs((prev) => {
      const next = prev.filter((t) => t.id !== id)
      if (activeSessionId === id) {
        setActiveSessionId(next.length ? next[next.length - 1].id : null)
      }
      return next
    })
  }

  const launchExternal = async (tab: SessionTab) => {
    const c = tab.connection
    const meta = protocolMeta(c.protocol)
    setPending(`connect:${c.target}`)
    setNotice({ kind: 'info', text: `Externo: ${meta.actionLabel} · ${c.target}…` })
    setShowLog(true)
    try {
      const r = await runLogged(meta.cliArgs(c))
      setSessionTabs((prev) =>
        prev.map((t) =>
          t.id === tab.id
            ? {
                ...t,
                state: r.code === 0 ? 'external' : 'error',
                note:
                  r.code === 0
                    ? 'Fallback externo lançado (Terminal/browser do SO).'
                    : r.stderr || r.stdout || 'Falha ao abrir externo',
              }
            : t,
        ),
      )
      if (r.code !== 0) {
        setNotice({
          kind: 'err',
          text: r.stderr || r.stdout || `Falha ao abrir ${c.target}`,
        })
        return
      }
      setNotice({
        kind: 'ok',
        text: `${meta.actionLabel} · ${c.target} — externo enviado.`,
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

  const sessionOn = !!status?.session && status?.token_ok !== false && !status?.need_login
  const wgUser = status?.warpgate_user || '—'
  const bastionHost = status?.bastion?.ssh_host || '—'
  const bastionPort = status?.bastion?.ssh_port
  const catalogUser = status?.user || '—'
  const authMode = status?.auth || 'none'
  const connCount = status?.connections ?? conns.length
  const tokenExpiry =
    status?.expires_at && status.expires_at > 0
      ? new Date(status.expires_at * 1000).toLocaleString()
      : null

  const pillLabel = !bootstrapped
    ? 'Carregando…'
    : status?.need_login
      ? 'Re-login SSO'
      : sessionOn
        ? `Ativo · ${catalogUser}`
        : 'Offline'

  return (
    <div className="app app-rdm">
      <div className={`busy-bar ${busy ? 'on' : ''}`} aria-hidden />

      <header className="topbar">
        <div className="brand">
          <div className="brand-mark" aria-hidden>
            <IconGate />
          </div>
          <div className="brand-text">
            <h1>ArchGate Connect</h1>
            <p className="subtitle">Bastion · sessões embutidas (RDM-lite)</p>
          </div>
        </div>
        <div className="topbar-actions">
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => {
              setPrefsTarget(null)
              setPrefsOpen(true)
            }}
            title="Fonte, cores e cursor dos terminais"
          >
            Preferências
          </button>
          <div
            className={`session-pill ${sessionOn ? 'on' : ''} ${!bootstrapped ? 'loading' : ''}`}
            role="status"
            aria-live="polite"
          >
            <span className="dot" />
            {pillLabel}
          </div>
        </div>
      </header>

      <div className="rdm-body">
      <aside className="rdm-sidebar">
      <main className="main main-sidebar">
        {sessionExpired && sessionOn ? (
          <div className="reconnect-banner" role="alert">
            <div>
              <strong>Sessão expirada</strong>
              <p>O token SSO caiu. Sessões embutidas devem ser reabertas após reconectar.</p>
            </div>
            <button
              type="button"
              className="btn btn-primary btn-sm"
              disabled={busy}
              onClick={() => void reconnectSso()}
            >
              Reconectar SSO
            </button>
          </div>
        ) : null}

        {!sessionOn ? (
          <div className="callout">
            <div className="callout-icon">
              <IconShield />
            </div>
            <div className="callout-body">
              <strong>Bastion, not VPN.</strong> Entre com SSO ArchGate. Forti/OpenVPN do
              cliente ficam no VPS — não no seu Mac.
            </div>
          </div>
        ) : null}

        <section className="panel panel-identity panel-identity-compact">
          <div className="identity-head">
            <div className="identity-avatar" aria-hidden>
              {(catalogUser || wgUser || '?').slice(0, 1).toUpperCase()}
            </div>
            <div className="identity-meta">
              {sessionOn ? (
                <>
                  <div className="identity-name" title={catalogUser}>
                    {catalogUser}
                    <span className="identity-badge">{authMode}</span>
                  </div>
                  <div className="identity-sub mono">
                    WG <strong>{wgUser}</strong>
                    <span className="dim">
                      {' '}
                      · {bastionHost}
                      {bastionPort != null ? `:${bastionPort}` : ''} · {connCount} conn
                    </span>
                  </div>
                  {tokenExpiry ? (
                    <div className="identity-sub dim">Token até {tokenExpiry}</div>
                  ) : null}
                </>
              ) : (
                <>
                  <div className="identity-name">Não autenticado</div>
                  <div className="identity-sub">Use SSO (Kanidm) para carregar o catálogo</div>
                </>
              )}
            </div>
            <div className="identity-actions">
              {!sessionOn ? (
                <button
                  className="btn btn-primary btn-sm"
                  disabled={busy}
                  onClick={() => void loginOidc()}
                  aria-busy={pending === 'sso'}
                >
                  {pending === 'sso' ? 'SSO…' : 'Login SSO'}
                </button>
              ) : (
                <button
                  className="btn btn-ghost btn-sm"
                  disabled={busy}
                  onClick={() => void reconnectSso()}
                  title="Renovar sessão SSO e limpar abas embutidas"
                >
                  Reconectar
                </button>
              )}
              <div className="menu-wrap">
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  aria-expanded={actionsOpen}
                  aria-haspopup="menu"
                  onClick={() => setActionsOpen((v) => !v)}
                >
                  ⋯
                </button>
                {actionsOpen ? (
                  <div className="menu-pop" role="menu">
                    <button
                      type="button"
                      role="menuitem"
                      disabled={busy}
                      onClick={() => {
                        setActionsOpen(false)
                        setNotice({ kind: 'info', text: 'Atualizando…' })
                        void refresh().then((st) => {
                          if (st?.session) {
                            setNotice({
                              kind: 'ok',
                              text: `Ativo · ${st.user || '—'} · WG ${st.warpgate_user || '—'}`,
                            })
                          }
                        })
                      }}
                    >
                      Atualizar catálogo
                    </button>
                    <button
                      type="button"
                      role="menuitem"
                      disabled={busy}
                      onClick={() => {
                        setActionsOpen(false)
                        void runDoctorCheck()
                      }}
                    >
                      Doctor
                    </button>
                    <button
                      type="button"
                      role="menuitem"
                      disabled={busy || !sessionOn}
                      onClick={() => {
                        setActionsOpen(false)
                        setPending('config')
                        void runLogged(['config', 'apply'])
                          .then((r) => {
                            setNotice({
                              kind: r.code === 0 ? 'ok' : 'err',
                              text:
                                r.code === 0
                                  ? r.stdout.trim() || 'SSH config aplicado'
                                  : r.stderr || 'Falha SSH config',
                            })
                          })
                          .finally(() => setPending(null))
                      }}
                    >
                      Aplicar SSH config
                    </button>
                    <button
                      type="button"
                      role="menuitem"
                      onClick={() => {
                        setActionsOpen(false)
                        setPrefsTarget(null)
                        setPrefsOpen(true)
                      }}
                    >
                      Preferências do terminal
                    </button>
                    <button
                      type="button"
                      role="menuitem"
                      onClick={() => {
                        setActionsOpen(false)
                        setShowAdvanced((v) => !v)
                      }}
                    >
                      {showAdvanced ? 'Ocultar avançado' : 'Avançado / homolog'}
                    </button>
                    <button
                      type="button"
                      role="menuitem"
                      disabled={busy || !sessionOn}
                      onClick={() => {
                        setActionsOpen(false)
                        void logout()
                      }}
                    >
                      Logout
                    </button>
                  </div>
                ) : null}
              </div>
            </div>
          </div>

          {sessionOn ? (
            <div className="wg-user-row">
              <label htmlFor="wg-user-field">
                Usuário Warpgate
                <span className="dim"> (SSH/DB no bastion)</span>
              </label>
              <div className="prefs-row">
                <input
                  id="wg-user-field"
                  className="field"
                  value={wgUserEdit}
                  onChange={(e) => setWgUserEdit(e.target.value)}
                  placeholder="ex.: uat-op-a ou seu.login"
                  spellCheck={false}
                  disabled={busy}
                />
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  disabled={busy || !wgUserEdit.trim()}
                  onClick={() => void saveWgUser()}
                >
                  Salvar
                </button>
              </div>
            </div>
          ) : null}

          {showAdvanced || homologMode ? (
            <div className="advanced-box">
              <div className="advanced-title">Avançado · homologação</div>
              <label className="prefs-check">
                <input
                  type="checkbox"
                  checked={homologMode}
                  onChange={(e) => {
                    const next = patchAppPrefs({ homologMode: e.target.checked })
                    setAppPrefs(next)
                  }}
                />
                Mostrar login lab (não usar em produção)
              </label>
              {homologMode ? (
                <div className="auth-row" style={{ marginTop: 8 }}>
                  <input
                    className="field"
                    value={user}
                    onChange={(e) => setUser(e.target.value)}
                    placeholder="usuário catálogo lab"
                    spellCheck={false}
                    disabled={busy}
                  />
                  <button
                    className="btn btn-ghost btn-sm"
                    disabled={busy}
                    onClick={() => void loginLab()}
                  >
                    {pending === 'lab' ? '…' : 'Lab'}
                  </button>
                </div>
              ) : null}
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                style={{ marginTop: 8 }}
                onClick={() => {
                  setShowOnboarding(true)
                  setAppPrefs(patchAppPrefs({ onboardingDone: false }))
                }}
              >
                Reabrir introdução
              </button>
            </div>
          ) : null}
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
                : 'Faça Lab (homolog) ou SSO (Kanidm) para carregar o catálogo.'}
              <div className="hint">
                Sessões <strong>embutidas</strong> no app (SSH, RDP/VNC/Guac, DB,
                Web). “Abrir externo” só como fallback. Warpgate:{' '}
                <strong>{wgUser}</strong>.
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
                      onClick={() => openSessionTab(c)}
                      aria-label={`Connect ${c.target}`}
                    >
                      {isConnecting ? '…' : 'Connect'}
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </section>
      </main>
      </aside>

      <section className="rdm-workspace">
        <SessionWorkspace
          tabs={sessionTabs}
          activeId={activeSessionId}
          onSelect={setActiveSessionId}
          onClose={closeSessionTab}
          onExternal={(tab) => void launchExternal(tab)}
          onSessionState={updateSessionState}
          onPrefs={(target) => {
            setPrefsTarget(target)
            setPrefsOpen(true)
          }}
          warpgateUser={wgUser}
          showPasswordTip={showWgTip}
          onDismissPasswordTip={() => {
            setAppPrefs(patchAppPrefs({ wgPasswordTipDismissed: true }))
          }}
          busy={busy}
        />
      </section>
      </div>

      {showOnboarding ? (
        <FirstRunWizard
          sessionOn={sessionOn}
          connCount={connCount}
          doctorOk={doctorOk}
          busy={busy}
          onSso={() => void loginOidc()}
          onDoctor={() => void runDoctorCheck()}
          onSkip={finishOnboarding}
          onFinish={finishOnboarding}
        />
      ) : null}

      <TerminalPrefsPanel
        open={prefsOpen}
        onClose={() => setPrefsOpen(false)}
        initialTarget={prefsTarget}
      />

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

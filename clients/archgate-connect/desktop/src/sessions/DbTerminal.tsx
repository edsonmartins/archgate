import { useCallback, useEffect, useRef, useState } from 'react'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'
import { runArchgate } from '../archgate'
import { toXtermTheme } from '../prefs/terminalPrefs'
import {
  useApplyTerminalOptions,
  useTerminalAppearance,
} from '../prefs/useTerminalAppearance'
import { WgPasswordTip } from './WgPasswordTip'

type DbInfo = {
  engine?: string
  host: string
  port: number
  database?: string
  username: string
  sslmode?: string
  program?: string
  args?: string[]
  psql?: string
  mysql?: string
  command?: string
  note?: string
}

type Props = {
  sessionId: string
  target: string
  active: boolean
  warpgateUser?: string
  showPasswordTip?: boolean
  onDismissPasswordTip?: () => void
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
}

function isTauri(): boolean {
  const w = window as unknown as { __TAURI_INTERNALS__?: unknown; __TAURI__?: unknown }
  return !!(w.__TAURI_INTERNALS__ || w.__TAURI__)
}

function isMySQL(info: DbInfo): boolean {
  const e = (info.engine || '').toLowerCase()
  return e === 'mysql' || e === 'mariadb' || !!info.mysql
}

/** Embedded psql/mysql via PTY against Warpgate DB bastion (password interactive). */
export function DbTerminal({
  sessionId,
  target,
  active,
  warpgateUser,
  showPasswordTip,
  onDismissPasswordTip,
  onState,
}: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const termRef = useRef<Terminal | null>(null)
  const fitRef = useRef<FitAddon | null>(null)
  const openedRef = useRef(false)
  const [banner, setBanner] = useState<string | null>(null)
  const appearance = useTerminalAppearance(target)
  const doFit = useCallback(() => {
    try {
      fitRef.current?.fit()
    } catch {
      /* ignore */
    }
  }, [])
  useApplyTerminalOptions(termRef, appearance, doFit)

  useEffect(() => {
    if (!hostRef.current || termRef.current) return

    const term = new Terminal({
      cursorBlink: appearance.cursorBlink,
      cursorStyle: appearance.cursorStyle,
      fontFamily: appearance.fontFamily,
      fontSize: appearance.fontSize,
      lineHeight: appearance.lineHeight,
      theme: toXtermTheme(appearance),
      allowProposedApi: true,
    })
    const fitAddon = new FitAddon()
    term.loadAddon(fitAddon)
    term.open(hostRef.current)
    fitAddon.fit()
    termRef.current = term
    fitRef.current = fitAddon

    term.writeln('\x1b[90mArchGate Connect · DB embutido (Warpgate bastion)\x1b[0m')
    term.writeln(`\x1b[90mAlvo: ${target}\x1b[0m`)
    term.writeln('')

    let unlistenData: (() => void) | undefined
    let unlistenExit: (() => void) | undefined
    let disposed = false

    const start = async () => {
      onState('connecting', 'Resolvendo bastion DB…')
      const r = await runArchgate(['db', target, '--json'])
      if (disposed) return
      if (r.code !== 0) {
        const err = (r.stderr || r.stdout || 'db falhou').trim()
        term.writeln(`\x1b[31m${err}\x1b[0m`)
        onState('error', err)
        setBanner(err)
        return
      }
      let info: DbInfo
      try {
        info = JSON.parse(r.stdout) as DbInfo
      } catch {
        onState('error', 'db JSON inválido')
        return
      }
      if (!info.host || !info.username) {
        onState('error', 'db incompleto')
        return
      }

      const mysql = isMySQL(info)
      const label = mysql ? 'MySQL' : 'Postgres'
      const cmdHint =
        info.command ||
        info.mysql ||
        info.psql ||
        `${mysql ? 'mysql' : 'psql'} ${info.host}:${info.port}`

      term.writeln(`\x1b[90m→ ${label} · ${cmdHint}\x1b[0m`)
      term.writeln(
        '\x1b[33mSenha: credencial Warpgate do operador (não a senha do banco).\x1b[0m',
      )
      if (mysql) {
        term.writeln(
          '\x1b[90mRequer mysql client no PATH e bastion com mysql.enable (porta 33306).\x1b[0m',
        )
      }
      term.writeln('')

      if (!isTauri()) {
        term.writeln('\x1b[33m(browser dev) PTY só no app Tauri.\x1b[0m')
        onState('error', 'DB embutido requer app desktop')
        return
      }

      const { invoke } = await import('@tauri-apps/api/core')
      const { listen } = await import('@tauri-apps/api/event')
      fitRef.current?.fit()

      let program = info.program || (mysql ? 'mysql' : 'psql')
      let args: string[] =
        info.args && info.args.length > 0
          ? info.args
          : mysql
            ? [
                '-h',
                info.host,
                '-P',
                String(info.port || 33306),
                '-u',
                info.username,
                '-p',
                '--ssl-mode=REQUIRED',
              ]
            : [
                `host=${info.host} port=${info.port} user=${info.username} dbname=${info.database || 'postgres'} sslmode=${info.sslmode || 'require'}`,
              ]

      try {
        await invoke('pty_session_open', {
          sessionId,
          program,
          args,
          cols: term.cols,
          rows: term.rows,
        })
        openedRef.current = true
        onState('connected', `${program} · ${info.username}@${info.host}`)
        setBanner(null)
      } catch (e) {
        const msg = String(e)
        term.writeln(`\x1b[31mFalha PTY ${program}: ${msg}\x1b[0m`)
        term.writeln(
          `\x1b[90mInstale ${program} no PATH ou use “Abrir externo” / copiar comando.\x1b[0m`,
        )
        onState('error', msg)
        setBanner(msg)
        return
      }

      unlistenData = await listen<{ session_id: string; data: string }>(
        'ssh-session-data',
        (ev) => {
          if (ev.payload.session_id !== sessionId) return
          term.write(ev.payload.data)
        },
      )
      unlistenExit = await listen<{ session_id: string }>(
        'ssh-session-exit',
        (ev) => {
          if (ev.payload.session_id !== sessionId) return
          openedRef.current = false
          term.writeln('\r\n\x1b[90m[sessão DB encerrada]\x1b[0m')
          onState('closed', 'Sessão DB encerrada')
        },
      )

      term.onData((data) => {
        if (!openedRef.current) return
        void invoke('ssh_session_write', { sessionId, data }).catch(() => {})
      })
      term.onResize(({ cols: c, rows: r }) => {
        if (!openedRef.current) return
        void invoke('ssh_session_resize', { sessionId, cols: c, rows: r }).catch(() => {})
      })
    }

    void start()
    const ro = new ResizeObserver(() => {
      try {
        fitRef.current?.fit()
      } catch {
        /* ignore */
      }
    })
    ro.observe(hostRef.current)

    return () => {
      disposed = true
      ro.disconnect()
      unlistenData?.()
      unlistenExit?.()
      if (openedRef.current && isTauri()) {
        void import('@tauri-apps/api/core').then(({ invoke }) =>
          invoke('ssh_session_close', { sessionId }).catch(() => {}),
        )
      }
      term.dispose()
      termRef.current = null
      fitRef.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId, target])

  useEffect(() => {
    if (!active) return
    const t = window.setTimeout(() => {
      try {
        fitRef.current?.fit()
        termRef.current?.focus()
      } catch {
        /* ignore */
      }
    }, 50)
    return () => window.clearTimeout(t)
  }, [active])

  return (
    <div className="ssh-terminal-wrap">
      {banner ? <div className="ssh-terminal-banner">{banner}</div> : null}
      {showPasswordTip && onDismissPasswordTip ? (
        <WgPasswordTip
          kind="db"
          warpgateUser={warpgateUser || 'operador'}
          onDismiss={onDismissPasswordTip}
        />
      ) : null}
      <div ref={hostRef} className="ssh-terminal-host" />
    </div>
  )
}

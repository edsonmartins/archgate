import { useEffect, useRef, useState } from 'react'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'
import { runArchgate } from '../archgate'

type PrintSsh = {
  host: string
  port: number
  user: string
  target?: string
  operator?: string
}

type Props = {
  sessionId: string
  target: string
  active: boolean
  onState: (state: 'connecting' | 'connected' | 'error' | 'closed', note?: string) => void
}

function isTauri(): boolean {
  const w = window as unknown as { __TAURI_INTERNALS__?: unknown; __TAURI__?: unknown }
  return !!(w.__TAURI_INTERNALS__ || w.__TAURI__)
}

export function SshTerminal({ sessionId, target, active, onState }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const termRef = useRef<Terminal | null>(null)
  const fitRef = useRef<FitAddon | null>(null)
  const openedRef = useRef(false)
  const [banner, setBanner] = useState<string | null>(null)

  useEffect(() => {
    if (!hostRef.current || termRef.current) return

    const term = new Terminal({
      cursorBlink: true,
      fontFamily: "'JetBrains Mono', ui-monospace, Menlo, monospace",
      fontSize: 13,
      lineHeight: 1.2,
      theme: {
        background: '#05080f',
        foreground: '#e2e8f0',
        cursor: '#38bdf8',
        selectionBackground: 'rgba(56, 189, 248, 0.28)',
        black: '#0f172a',
        red: '#fb7185',
        green: '#34d399',
        yellow: '#fbbf24',
        blue: '#38bdf8',
        magenta: '#a78bfa',
        cyan: '#22d3ee',
        white: '#e2e8f0',
        brightBlack: '#64748b',
        brightRed: '#fda4af',
        brightGreen: '#6ee7b7',
        brightYellow: '#fde68a',
        brightBlue: '#7dd3fc',
        brightMagenta: '#c4b5fd',
        brightCyan: '#67e8f9',
        brightWhite: '#f8fafc',
      },
      allowProposedApi: true,
    })
    const fit = new FitAddon()
    term.loadAddon(fit)
    term.open(hostRef.current)
    fit.fit()
    termRef.current = term
    fitRef.current = fit

    term.writeln('\x1b[90mArchGate Connect · SSH embutido (Warpgate bastion)\x1b[0m')
    term.writeln(`\x1b[90mAlvo: ${target}\x1b[0m`)
    term.writeln('')

    let unlistenData: (() => void) | undefined
    let unlistenExit: (() => void) | undefined
    let disposed = false

    const start = async () => {
      onState('connecting', 'Resolvendo bastion…')
      const r = await runArchgate(['print-ssh', target, '--json'])
      if (disposed) return
      if (r.code !== 0) {
        const err = (r.stderr || r.stdout || 'print-ssh falhou').trim()
        term.writeln(`\x1b[31m${err}\x1b[0m`)
        onState('error', err)
        setBanner(err)
        return
      }
      let info: PrintSsh
      try {
        info = JSON.parse(r.stdout) as PrintSsh
      } catch {
        term.writeln('\x1b[31mJSON inválido de print-ssh\x1b[0m')
        onState('error', 'print-ssh JSON inválido')
        return
      }
      if (!info.host || !info.user || !info.port) {
        onState('error', 'print-ssh incompleto')
        term.writeln('\x1b[31mprint-ssh incompleto (host/user/port)\x1b[0m')
        return
      }

      term.writeln(
        `\x1b[90m→ ssh -p ${info.port} ${info.user}@${info.host}\x1b[0m`,
      )
      if (info.operator) {
        term.writeln(
          `\x1b[33mSenha Warpgate: use a senha do operador «${info.operator}» (não o nickname do catálogo).\x1b[0m`,
        )
      }
      term.writeln('')

      if (!isTauri()) {
        term.writeln(
          '\x1b[33m(browser dev) PTY SSH só no app Tauri. Use “Abrir externo” ou `tauri:dev`.\x1b[0m',
        )
        onState('error', 'SSH embutido requer app desktop')
        setBanner('SSH embutido só no binário Tauri')
        return
      }

      const { invoke } = await import('@tauri-apps/api/core')
      const { listen } = await import('@tauri-apps/api/event')

      fit.fit()
      const cols = term.cols
      const rows = term.rows

      try {
        await invoke('ssh_session_open', {
          sessionId,
          host: info.host,
          port: info.port,
          user: info.user,
          cols,
          rows,
        })
        openedRef.current = true
        onState('connected', `SSH · ${info.user}@${info.host}:${info.port}`)
        setBanner(null)
      } catch (e) {
        const msg = String(e)
        term.writeln(`\x1b[31mFalha ao abrir PTY: ${msg}\x1b[0m`)
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
      unlistenExit = await listen<{ session_id: string; code?: number }>(
        'ssh-session-exit',
        (ev) => {
          if (ev.payload.session_id !== sessionId) return
          openedRef.current = false
          term.writeln('\r\n\x1b[90m[sessão SSH encerrada]\x1b[0m')
          onState('closed', 'Sessão SSH encerrada')
        },
      )

      term.onData((data) => {
        if (!openedRef.current) return
        void invoke('ssh_session_write', { sessionId, data }).catch(() => {
          /* ignore write after exit */
        })
      })

      term.onResize(({ cols: c, rows: r }) => {
        if (!openedRef.current) return
        void invoke('ssh_session_resize', { sessionId, cols: c, rows: r }).catch(() => {})
      })
    }

    void start()

    const ro = new ResizeObserver(() => {
      try {
        fit.fit()
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
        openedRef.current = false
      }
      term.dispose()
      termRef.current = null
      fitRef.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- one PTY per sessionId
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
      <div ref={hostRef} className="ssh-terminal-host" />
    </div>
  )
}

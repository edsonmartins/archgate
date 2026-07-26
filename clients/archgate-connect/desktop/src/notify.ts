/**
 * Lightweight native notifications (F13).
 * Uses Web Notification API (works in Tauri webview on macOS after permission).
 */

let permissionAsked = false

async function ensurePermission(): Promise<boolean> {
  if (typeof Notification === 'undefined') return false
  if (Notification.permission === 'granted') return true
  if (Notification.permission === 'denied') return false
  if (permissionAsked) return false
  permissionAsked = true
  try {
    const p = await Notification.requestPermission()
    return p === 'granted'
  } catch {
    return false
  }
}

export async function notify(opts: {
  title: string
  body?: string
  tag?: string
}): Promise<void> {
  try {
    const ok = await ensurePermission()
    if (!ok) return
    const n = new Notification(opts.title, {
      body: opts.body,
      tag: opts.tag || 'archgate-connect',
      silent: false,
    })
    // Auto-close after a few seconds so tray doesn't pile up.
    window.setTimeout(() => n.close(), 8000)
  } catch {
    /* ignore — notifications are best-effort */
  }
}

export function notifySession(
  kind: 'connected' | 'closed' | 'error' | 'token',
  target: string,
  detail?: string,
): void {
  const titles: Record<typeof kind, string> = {
    connected: 'Sessão conectada',
    closed: 'Sessão encerrada',
    error: 'Erro de sessão',
    token: 'Sessão SSO',
  }
  void notify({
    title: `ArchGate · ${titles[kind]}`,
    body: detail ? `${target} — ${detail}` : target,
    tag: `ag-${kind}-${target}`,
  })
}

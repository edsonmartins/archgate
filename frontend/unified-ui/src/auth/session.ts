/**
 * Session store until full OIDC cookie BFF (W4).
 * Production: prefer HttpOnly session cookie from BFF; SPA holds display profile only.
 * Never store admin tokens (W4-UI05).
 */

const KEY = 'archgate.unified.session'

export type UserSession = {
  displayName: string
  email: string
  tenants: string[]
  /** mock lab | OIDC ArchGuard */
  mode: 'mock' | 'oidc'
  /** Warpgate username (preferred_username) for launch snippets */
  username?: string
}

export function getSession(): UserSession | null {
  try {
    const raw = sessionStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as UserSession) : null
  } catch {
    return null
  }
}

export function setMockSession(): UserSession {
  const s: UserSession = {
    displayName: 'Operador Lab (mock)',
    email: 'uat-op-a@archgate.com.br',
    tenants: ['tenant_rio_quality'],
    mode: 'mock',
    username: 'uat-op-a',
  }
  sessionStorage.setItem(KEY, JSON.stringify(s))
  return s
}

export function setOidcSession(s: UserSession): UserSession {
  const next: UserSession = { ...s, mode: 'oidc' }
  sessionStorage.setItem(KEY, JSON.stringify(next))
  return next
}

export function clearSession(): void {
  sessionStorage.removeItem(KEY)
}

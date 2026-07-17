/**
 * Session placeholder until OIDC Code+PKCE is wired (W4-UI02).
 * Production: never store admin tokens; only user id_token / access for BFF.
 */

const KEY = 'archgate.unified.session'

export type UserSession = {
  displayName: string
  email: string
  tenants: string[]
  /** mock | oidc */
  mode: 'mock' | 'oidc'
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
  }
  sessionStorage.setItem(KEY, JSON.stringify(s))
  return s
}

export function clearSession(): void {
  sessionStorage.removeItem(KEY)
}

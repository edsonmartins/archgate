/**
 * OIDC Code+PKCE against Kanidm (scaffold).
 * Lab default: mock session (session.ts). Enable with VITE_OIDC_ENABLED=1
 * after registering client `archgate-unified-ui` on id.archgate.com.br.
 */

import { config } from '../config'
import { createPkcePair, randomString } from './pkce'
import type { UserSession } from './session'
import { clearSession, setOidcSession } from './session'

const PKCE_KEY = 'archgate.unified.pkce'
const STATE_KEY = 'archgate.unified.oidc_state'

type StoredPkce = {
  verifier: string
  state: string
  nonce: string
}

function issuerBase(): string {
  // Kanidm OpenID path: …/oauth2/openid/<client>
  return config.oidc.issuer.replace(/\/$/, '')
}

export function isOidcEnabled(): boolean {
  return config.oidc.enabled
}

export async function beginOidcLogin(): Promise<void> {
  const { verifier, challenge } = await createPkcePair()
  const state = randomString(16)
  const nonce = randomString(16)
  const stored: StoredPkce = { verifier, state, nonce }
  sessionStorage.setItem(PKCE_KEY, JSON.stringify(stored))
  sessionStorage.setItem(STATE_KEY, state)

  const authUrl = new URL(`${issuerBase()}/authorize`)
  authUrl.searchParams.set('response_type', 'code')
  authUrl.searchParams.set('client_id', config.oidc.clientId)
  authUrl.searchParams.set('redirect_uri', config.oidc.redirectUri)
  authUrl.searchParams.set('scope', config.oidc.scopes)
  authUrl.searchParams.set('state', state)
  authUrl.searchParams.set('nonce', nonce)
  authUrl.searchParams.set('code_challenge', challenge)
  authUrl.searchParams.set('code_challenge_method', 'S256')

  window.location.assign(authUrl.toString())
}

/**
 * Exchange code at BFF when available. Browser-only token exchange is allowed
 * for public clients with PKCE; prefer BFF for production hardening.
 */
export async function completeOidcCallback(search: string): Promise<UserSession> {
  const params = new URLSearchParams(search.startsWith('?') ? search.slice(1) : search)
  const err = params.get('error')
  if (err) {
    throw new Error(`OIDC error: ${err} ${params.get('error_description') ?? ''}`.trim())
  }
  const code = params.get('code')
  const state = params.get('state')
  if (!code || !state) {
    throw new Error('OIDC callback missing code/state')
  }

  const raw = sessionStorage.getItem(PKCE_KEY)
  if (!raw) throw new Error('PKCE verifier missing — restart login')
  const stored = JSON.parse(raw) as StoredPkce
  if (stored.state !== state) throw new Error('OIDC state mismatch')

  // Prefer BFF exchange (no SPA token storage of refresh if BFF sets cookie)
  const bff = await tryBffExchange(code, stored.verifier)
  if (bff) {
    sessionStorage.removeItem(PKCE_KEY)
    sessionStorage.removeItem(STATE_KEY)
    return setOidcSession(bff)
  }

  // Fallback: public client token endpoint (lab / early)
  const token = await exchangeCodeDirect(code, stored.verifier)
  sessionStorage.removeItem(PKCE_KEY)
  sessionStorage.removeItem(STATE_KEY)

  const claims = decodeJwtPayload(token.id_token ?? token.access_token)
  const session: UserSession = {
    displayName: String(claims.name ?? claims.preferred_username ?? 'Operador'),
    email: String(claims.email ?? claims.preferred_username ?? ''),
    tenants: extractTenants(claims),
    mode: 'oidc',
    username: String(claims.preferred_username ?? claims.sub ?? ''),
  }
  return setOidcSession(session)
}

async function tryBffExchange(
  code: string,
  verifier: string,
): Promise<UserSession | null> {
  try {
    const res = await fetch(`${config.apiBase}/unified/v1/auth/callback`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({
        code,
        code_verifier: verifier,
        redirect_uri: config.oidc.redirectUri,
      }),
    })
    if (!res.ok) return null
    const data = (await res.json()) as {
      display_name?: string
      email?: string
      tenants?: string[]
      username?: string
    }
    return {
      displayName: data.display_name ?? 'Operador',
      email: data.email ?? '',
      tenants: data.tenants ?? [],
      mode: 'oidc',
      username: data.username,
    }
  } catch {
    return null
  }
}

async function exchangeCodeDirect(
  code: string,
  verifier: string,
): Promise<{ access_token: string; id_token?: string }> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: config.oidc.clientId,
    code,
    redirect_uri: config.oidc.redirectUri,
    code_verifier: verifier,
  })
  const res = await fetch(`${issuerBase()}/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  })
  if (!res.ok) {
    const t = await res.text()
    throw new Error(`Token exchange failed (${res.status}): ${t.slice(0, 200)}`)
  }
  return (await res.json()) as { access_token: string; id_token?: string }
}

function decodeJwtPayload(jwt: string): Record<string, unknown> {
  const parts = jwt.split('.')
  if (parts.length < 2) return {}
  const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
  return JSON.parse(json) as Record<string, unknown>
}

function extractTenants(claims: Record<string, unknown>): string[] {
  const groups = claims.groups
  if (Array.isArray(groups)) {
    return groups
      .map(String)
      .filter((g) => g.startsWith('tenant_') || g.includes('tenant'))
  }
  if (typeof claims.tenant === 'string') return [claims.tenant]
  // Lab default if IdP omits groups claim mapping
  return ['tenant_rio_quality']
}

export function logoutOidc(): void {
  clearSession()
  sessionStorage.removeItem(PKCE_KEY)
  sessionStorage.removeItem(STATE_KEY)
}

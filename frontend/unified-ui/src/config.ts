/**
 * Runtime config for UnifiedUI (Vite env).
 * Secrets never belong here — only public OIDC client id + endpoints.
 */

function flag(v: string | undefined): boolean {
  return v === '1' || v === 'true' || v === 'yes'
}

export const config = {
  apiBase: import.meta.env.VITE_API_BASE ?? '/api',
  oidc: {
    enabled: flag(import.meta.env.VITE_OIDC_ENABLED),
    issuer: import.meta.env.VITE_OIDC_ISSUER ?? 'https://id.archgate.com.br/oauth2/openid/archgate-unified-ui',
    clientId: import.meta.env.VITE_OIDC_CLIENT_ID ?? 'archgate-unified-ui',
    redirectUri:
      import.meta.env.VITE_OIDC_REDIRECT_URI ??
      (typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : 'http://localhost:5174/auth/callback'),
    scopes: import.meta.env.VITE_OIDC_SCOPES ?? 'openid profile email',
  },
  warpgate: {
    sshHost: import.meta.env.VITE_WG_SSH_HOST ?? 'wg.archgate.com.br',
    sshPort: Number(import.meta.env.VITE_WG_SSH_PORT ?? 2222),
    pgHost: import.meta.env.VITE_WG_PG_HOST ?? 'wg.archgate.com.br',
    pgPort: Number(import.meta.env.VITE_WG_PG_PORT ?? 55432),
    pgDb: import.meta.env.VITE_WG_PG_DB ?? 'archgate_lab',
    /** Public HTTPS base for HTTP targets (observability / apps). */
    httpBase:
      import.meta.env.VITE_WG_HTTP_BASE ??
      import.meta.env.VITE_WG_PUBLIC_URL ??
      'https://wg.archgate.com.br',
  },
  guac: {
    /** Allow demo tunnel when BFF missing (local chrome only). */
    demo: flag(import.meta.env.VITE_GUAC_DEMO),
    /** Optional direct WS override (normally from BFF response). */
    tunnelWs: import.meta.env.VITE_GUAC_TUNNEL_WS ?? '',
  },
} as const

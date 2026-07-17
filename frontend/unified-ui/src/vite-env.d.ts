/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE?: string
  readonly VITE_OIDC_ENABLED?: string
  readonly VITE_OIDC_ISSUER?: string
  readonly VITE_OIDC_CLIENT_ID?: string
  readonly VITE_OIDC_REDIRECT_URI?: string
  readonly VITE_OIDC_SCOPES?: string
  readonly VITE_WG_SSH_HOST?: string
  readonly VITE_WG_SSH_PORT?: string
  readonly VITE_WG_PG_HOST?: string
  readonly VITE_WG_PG_PORT?: string
  readonly VITE_WG_PG_DB?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare module '*.css' {
  const css: string
  export default css
}

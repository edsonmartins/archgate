/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ARCHGATE_MOCK?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

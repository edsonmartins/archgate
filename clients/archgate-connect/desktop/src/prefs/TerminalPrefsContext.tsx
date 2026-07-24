import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import {
  clearTargetOverride,
  defaultStore,
  loadPrefs,
  resolveAppearance,
  savePrefs,
  setGlobal,
  setTargetOverride,
  type TerminalAppearance,
  type TerminalPrefsStore,
} from './terminalPrefs'

type Ctx = {
  store: TerminalPrefsStore
  /** Resolved appearance for optional target (global if no override). */
  appearanceFor: (target?: string | null) => TerminalAppearance
  updateGlobal: (patch: Partial<TerminalAppearance>) => void
  updateTarget: (target: string, patch: Partial<TerminalAppearance>) => void
  resetTarget: (target: string) => void
  resetAll: () => void
}

const TerminalPrefsContext = createContext<Ctx | null>(null)

export function TerminalPrefsProvider({ children }: { children: ReactNode }) {
  const [store, setStore] = useState<TerminalPrefsStore>(() => loadPrefs())

  const persist = useCallback((next: TerminalPrefsStore) => {
    setStore(next)
    savePrefs(next)
  }, [])

  const appearanceFor = useCallback(
    (target?: string | null) => resolveAppearance(store, target),
    [store],
  )

  const updateGlobal = useCallback(
    (patch: Partial<TerminalAppearance>) => {
      persist(setGlobal(store, patch))
    },
    [persist, store],
  )

  const updateTarget = useCallback(
    (target: string, patch: Partial<TerminalAppearance>) => {
      persist(setTargetOverride(store, target, patch))
    },
    [persist, store],
  )

  const resetTarget = useCallback(
    (target: string) => {
      persist(clearTargetOverride(store, target))
    },
    [persist, store],
  )

  const resetAll = useCallback(() => {
    persist(defaultStore())
  }, [persist])

  const value = useMemo(
    () => ({
      store,
      appearanceFor,
      updateGlobal,
      updateTarget,
      resetTarget,
      resetAll,
    }),
    [store, appearanceFor, updateGlobal, updateTarget, resetTarget, resetAll],
  )

  return (
    <TerminalPrefsContext.Provider value={value}>{children}</TerminalPrefsContext.Provider>
  )
}

export function useTerminalPrefs(): Ctx {
  const ctx = useContext(TerminalPrefsContext)
  if (!ctx) {
    throw new Error('useTerminalPrefs requires TerminalPrefsProvider')
  }
  return ctx
}

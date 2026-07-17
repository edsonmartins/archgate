import { useState } from 'react'
import type { LaunchBundle } from '../launch/warpgate'
import { copyText, tryOpenUri } from '../launch/warpgate'

type Props = {
  bundle: LaunchBundle
}

export function LaunchSnippets({ bundle }: Props) {
  const [copied, setCopied] = useState<string | null>(null)

  async function onCopy(id: string, body: string) {
    const ok = await copyText(body)
    setCopied(ok ? id : 'err')
    window.setTimeout(() => setCopied(null), 2000)
  }

  return (
    <div className="launch-block">
      <p className="muted" style={{ marginTop: 0 }}>
        Parte B (desktop) — bastion-first. Target <code>{bundle.target}</code> · user{' '}
        <code>{bundle.username}</code>. Sem IP de alvo (ADR-008).
      </p>
      {bundle.snippets.map((s) => (
        <div key={s.id} className="snippet">
          <div className="snippet-head">
            <strong>{s.label}</strong>
            <span style={{ flex: 1 }} />
            {s.uri && (
              <button
                type="button"
                className="btn"
                onClick={() => void tryOpenUri(s.uri!)}
                title={s.uri}
              >
                Abrir deep-link
              </button>
            )}
            <button type="button" className="btn" onClick={() => void onCopy(s.id, s.body)}>
              {copied === s.id ? 'Copiado' : copied === 'err' ? 'Falhou' : 'Copiar'}
            </button>
          </div>
          <pre className="code">{s.body}</pre>
        </div>
      ))}
    </div>
  )
}

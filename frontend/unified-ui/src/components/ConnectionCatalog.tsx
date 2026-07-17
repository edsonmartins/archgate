import type { Connection } from '../types'

type Props = {
  connections: Connection[]
  selectedId: string | null
  onSelect: (c: Connection) => void
}

export function ConnectionCatalog({ connections, selectedId, onSelect }: Props) {
  if (connections.length === 0) {
    return (
      <div className="card">
        <h2>Minhas conexões</h2>
        <p className="muted">
          Sem conexões para o seu tenant. Peça acesso ao admin ou verifique o grupo Kanidm.
        </p>
      </div>
    )
  }

  return (
    <div className="card">
      <h2>Minhas conexões</h2>
      <p className="muted" style={{ marginTop: 0 }}>
        Filtrado por tenant da sessão (mock lab). IPs de alvo nunca expostos.
      </p>
      <table className="table">
        <thead>
          <tr>
            <th>Nome</th>
            <th>Site</th>
            <th>Protocolo</th>
            <th>Engine</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {connections.map((c) => (
            <tr
              key={c.id}
              style={{
                background: selectedId === c.id ? 'var(--accent-dim)' : undefined,
              }}
            >
              <td>{c.name}</td>
              <td className="muted">{c.site}</td>
              <td>
                <span className={`badge ${c.protocol}`}>{c.protocol}</span>
              </td>
              <td className="muted">{c.engine}</td>
              <td>
                <button type="button" className="btn" onClick={() => onSelect(c)}>
                  Abrir
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

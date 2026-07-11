# ADR-005 — Nome do produto: ArchGate

- **Status:** Aceito (pendente checagem formal de marca/domínio)
- **Data:** julho de 2026
- **Relacionado:** documento de arquitetura §16 (ADR-005); ArchGuard (módulo de identidade)

## Contexto

A plataforma de acesso privilegiado precisa de um nome. O produto já contém o **ArchGuard** (console/identidade sobre Kanidm) como um de seus módulos, o que torna a decisão de nome também uma decisão de arquitetura de marca: o produto ganha nome próprio, ou o ArchGuard vira o guarda-chuva?

Convenções de marca da IntegrAllTech:
- **Família Arch-** (marca-casa): ArchFlow (runtime), ArchGuard (identidade/acesso), Archbase (componentes).
- **Família -Lenz** (visibilidade): DocLenz, DeskLenz, ReportLenz.
- **Família X** (.ai/.dev): VendaX.ai, RouteX.dev, SquadX.dev.

Um bastion/gateway de acesso é sobre **controlar e barrar acesso**, o que encaixa na família Arch (segurança/infra) e destoa da família Lenz (visibilidade).

## Decisão

O produto se chama **ArchGate** — a plataforma de acesso privilegiado, irmã de ArchFlow e ArchGuard na família Arch.

O **ArchGuard** permanece como o **módulo de identidade e acesso** dentro do ArchGate. A proximidade entre os nomes é tratada como **par intencional**, não colisão:

- **ArchGate** = a plataforma / o portão por onde se passa (o "como se entra").
- **ArchGuard** = o guarda no portão que confere identidade (o "quem é você").

Narrativa: *o Guard controla quem passa pelo Gate.*

## Consequências

**Positivas:** encaixa na marca-casa Arch; reaproveita o ArchGuard como módulo com narrativa clara; "Gate" comunica gateway/bastion de imediato.

**Negativas / cuidados:**
- **Disciplina de comunicação** necessária para não confundir ArchGate (plataforma) e ArchGuard (módulo), sobretudo em contexto verbal. Padrão sugerido: "plataforma ArchGate" e "módulo de identidade ArchGuard".
- **Similaridade com AppGate** (fornecedor ZTNA consolidado, mesma categoria de acesso zero-trust). "ArchGate" e "AppGate" são próximos foneticamente e concorrem no mesmo espaço conceitual.

## Riscos e mitigações

- **Marca/confusão com AppGate** → **checagem formal de marca (INPI/registro) antes de comprometer**; avaliar diferenciação clara de posicionamento e identidade visual.
- **Disponibilidade de domínio** (archgate.dev / .com / .app / .io) → verificar e registrar antes de divulgação externa.
- **Confusão interna Gate × Guard** → convenção de nomenclatura documentada e usada consistentemente.

## Pendências antes de gravar em definitivo

1. Checagem de marca (não colidir com AppGate e correlatos).
2. Verificação e registro de domínio.
3. Confirmação da convenção "plataforma ArchGate / módulo ArchGuard" com a equipe.

## Referências

- Busca de mercado: não há produto de software "ArchGate" identificado em PAM; AppGate existe em ZTNA.
- Documento de arquitetura, §16 (ADR-005).

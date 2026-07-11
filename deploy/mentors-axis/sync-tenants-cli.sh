#!/usr/bin/env bash
# Ops CLI: Axis → sites (Postgres) + Kanidm tenant_* + Warpgate roles
# Mirrors console syncMentorsAxisTenantsFn for lab bootstrap without browser session.
#
# Usage (on runtime host):
#   source /root/archgate/bootstrap.env
#   bash deploy/mentors-axis/sync-tenants-cli.sh
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-/root/archgate/bootstrap.env}"
[[ -f "$BOOTSTRAP" ]] && set -a && # shellcheck disable=SC1090
  source "$BOOTSTRAP" && set +a

# Prefer console container env (Swarm DNS + secrets already set)
CID=""
if docker ps -q --filter name=archgate-id_archguard-console | head -1 | grep -q .; then
  CID=$(docker ps -q --filter name=archgate-id_archguard-console | head -1)
fi

if [[ -n "$CID" ]]; then
  AXIS_URL=$(docker exec "$CID" printenv MENTORS_AXIS_URL 2>/dev/null || true)
  AXIS_EMAIL=$(docker exec "$CID" printenv MENTORS_AXIS_EMAIL 2>/dev/null || true)
  AXIS_PASS=$(docker exec "$CID" printenv MENTORS_AXIS_PASSWORD 2>/dev/null || true)
  AXIS_TOKEN=$(docker exec "$CID" printenv MENTORS_AXIS_TOKEN 2>/dev/null || true)
  TENANT_ID=$(docker exec "$CID" printenv MENTORS_AXIS_TENANT_ID 2>/dev/null || true)
  CONSOLE_DATABASE_URL=$(docker exec "$CID" printenv CONSOLE_DATABASE_URL 2>/dev/null || true)
  KANIDM_URL=$(docker exec "$CID" printenv ARCHGUARD_ID_URL 2>/dev/null || true)
  KANIDM_SA=$(docker exec "$CID" printenv ARCHGUARD_SA_TOKEN 2>/dev/null || true)
  WG_URL=$(docker exec "$CID" printenv WARPGATE_URL 2>/dev/null || true)
  WG_HOST=$(docker exec "$CID" printenv WARPGATE_HOST 2>/dev/null || true)
  WG_USER=$(docker exec "$CID" printenv WARPGATE_ADMIN_USER 2>/dev/null || true)
  WG_PASS=$(docker exec "$CID" printenv WARPGATE_ADMIN_PASSWORD 2>/dev/null || true)
fi

AXIS_URL="${AXIS_URL:-${MENTORS_AXIS_URL:-http://127.0.0.1:9031}}"
# Host-only: Swarm DNS not resolvable outside containers
if [[ -z "$CID" && "$AXIS_URL" == *"archgate-axis-spring"* ]]; then
  AXIS_URL="${AXIS_URL_HOST:-http://127.0.0.1:9031}"
fi
AXIS_EMAIL="${AXIS_EMAIL:-${MENTORS_AXIS_EMAIL:-admin@mentorsaxis.com}}"
AXIS_PASS="${AXIS_PASS:-${MENTORS_AXIS_PASSWORD:-}}"
AXIS_TOKEN="${AXIS_TOKEN:-${MENTORS_AXIS_TOKEN:-}}"
TENANT_ID="${TENANT_ID:-${MENTORS_AXIS_TENANT_ID:-a9f814d2-4dae-41f3-851b-8aa3d4706561}}"
KANIDM_URL="${KANIDM_URL:-${ARCHGUARD_ID_URL:-https://id.archgate.com.br}}"
KANIDM_SA="${KANIDM_SA:-${ARCHGUARD_SA_TOKEN:-}}"
WG_URL="${WG_URL:-${WARPGATE_URL:-https://wg.archgate.com.br}}"
WG_HOST="${WG_HOST:-${WARPGATE_HOST:-wg.archgate.com.br}}"
WG_USER="${WG_USER:-${WARPGATE_ADMIN_USER:-admin}}"
WG_PASS="${WG_PASS:-${WARPGATE_ADMIN_PASSWORD:-}}"
CONSOLE_DATABASE_URL="${CONSOLE_DATABASE_URL:-}"
: "${CONSOLE_DATABASE_URL:?CONSOLE_DATABASE_URL required (sites SoT)}"

echo "==> Axis: $AXIS_URL  tenant=$TENANT_ID"
echo "==> Sites SoT: CONSOLE_DATABASE_URL set"
echo "==> Kanidm: ${KANIDM_URL}  SA=${KANIDM_SA:+yes}"
echo "==> Warpgate: ${WG_URL}  admin=${WG_PASS:+yes}"
echo "==> Runner: ${CID:+console container}${CID:-host node}"

export AXIS_URL AXIS_EMAIL AXIS_PASS AXIS_TOKEN TENANT_ID
export KANIDM_URL KANIDM_SA WG_URL WG_HOST WG_USER WG_PASS
export CONSOLE_DATABASE_URL
export NODE_TLS_REJECT_UNAUTHORIZED="${NODE_TLS_REJECT_UNAUTHORIZED:-0}"

run_node() {
  if [[ -n "$CID" ]]; then
    docker exec -i \
      -e AXIS_URL -e AXIS_EMAIL -e AXIS_PASS -e AXIS_TOKEN -e TENANT_ID \
      -e KANIDM_URL -e KANIDM_SA -e WG_URL -e WG_HOST -e WG_USER -e WG_PASS \
      -e CONSOLE_DATABASE_URL -e NODE_TLS_REJECT_UNAUTHORIZED \
      "$CID" node --input-type=module
  else
    node --input-type=module
  fi
}

run_node <<'NODE'
import pg from 'pg';

const AXIS_URL = (process.env.AXIS_URL || '').replace(/\/$/, '');
const TENANT_ID = process.env.TENANT_ID || '';
const KANIDM_URL = (process.env.KANIDM_URL || '').replace(/\/$/, '');
const KANIDM_SA = process.env.KANIDM_SA || '';
const WG_URL = (process.env.WG_URL || '').replace(/\/$/, '');
const WG_HOST = process.env.WG_HOST || '';
const WG_USER = process.env.WG_USER || 'admin';
const WG_PASS = process.env.WG_PASS || '';
const DB = process.env.CONSOLE_DATABASE_URL;

function slugify(raw) {
  return String(raw || 'cliente')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'cliente';
}

/** Prefer human description; avoid UUID fragments as primary slug. */
function siteSlug(code, descricao, id) {
  const c = String(code || '').trim();
  const looksUuidFrag = /^[0-9a-f]{6,}$/i.test(c) || /^\d+$/.test(c);
  if (c && !looksUuidFrag) return slugify(c);
  if (descricao) return slugify(descricao);
  if (c) return slugify(c);
  return slugify(id);
}

async function axisToken() {
  if (process.env.AXIS_TOKEN) return process.env.AXIS_TOKEN;
  const res = await fetch(`${AXIS_URL}/api/v1/auth/authenticate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: process.env.AXIS_EMAIL,
      password: process.env.AXIS_PASS,
    }),
  });
  const j = await res.json();
  if (!res.ok || !j.access_token) {
    throw new Error(`Axis login ${res.status}: ${JSON.stringify(j).slice(0, 200)}`);
  }
  return j.access_token;
}

async function listProprietarios(token) {
  const res = await fetch(
    `${AXIS_URL}/api/v1/proprietario/findAll?page=0&size=200`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-TENANT-IDs': TENANT_ID,
        Accept: 'application/json',
      },
    },
  );
  const j = await res.json();
  if (!res.ok) throw new Error(`findAll ${res.status}: ${JSON.stringify(j).slice(0, 200)}`);
  return j.content || (Array.isArray(j) ? j : []);
}

async function ensureKanidmGroup(name, description) {
  if (!KANIDM_SA) return { action: 'skipped', detail: 'no SA' };
  const get = await fetch(`${KANIDM_URL}/v1/group/${encodeURIComponent(name)}`, {
    headers: { Authorization: `Bearer ${KANIDM_SA}` },
  });
  if (get.ok) return { action: 'exists', detail: name };
  if (get.status !== 404) {
    const t = await get.text();
    return { action: 'error', detail: `GET ${get.status} ${t.slice(0, 120)}` };
  }
  const create = await fetch(`${KANIDM_URL}/v1/group`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${KANIDM_SA}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      attrs: {
        name: [name],
        description: [description || `ArchGate tenant ${name}`],
      },
    }),
  });
  if (create.ok || create.status === 200 || create.status === 201) {
    return { action: 'created', detail: name };
  }
  const t = await create.text();
  if (create.status === 409 || /already/i.test(t)) return { action: 'exists', detail: name };
  return { action: 'error', detail: `POST ${create.status} ${t.slice(0, 120)}` };
}

async function warpgateLogin() {
  if (!WG_PASS) return null;
  const res = await fetch(`${WG_URL}/@warpgate/api/auth/login`, {
    method: 'POST',
    headers: {
      Host: WG_HOST,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ username: WG_USER, password: WG_PASS }),
  });
  if (!res.ok) throw new Error(`Warpgate login ${res.status}`);
  let cookies = '';
  try {
    const arr = typeof res.headers.getSetCookie === 'function' ? res.headers.getSetCookie() : [];
    if (arr.length) cookies = arr.map((c) => c.split(';')[0]).join('; ');
  } catch { /* ignore */ }
  if (!cookies) {
    const raw = res.headers.get('set-cookie');
    if (raw) {
      cookies = raw
        .split(/,(?=[^;]+?=)/)
        .map((c) => c.split(';')[0].trim())
        .filter(Boolean)
        .join('; ');
    }
  }
  return cookies;
}

async function ensureWarpgateRole(cookie, name, description) {
  if (!cookie) return { action: 'skipped', detail: 'no warpgate' };
  const listRes = await fetch(`${WG_URL}/@warpgate/admin/api/roles`, {
    headers: { Host: WG_HOST, Cookie: cookie },
  });
  if (!listRes.ok) throw new Error(`list roles ${listRes.status}`);
  const roles = await listRes.json();
  if (roles.find((r) => r.name === name)) return { action: 'exists', detail: name };
  const create = await fetch(`${WG_URL}/@warpgate/admin/api/roles`, {
    method: 'POST',
    headers: {
      Host: WG_HOST,
      Cookie: cookie,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      name,
      description: description || `ArchGate ${name}`,
      is_default: false,
    }),
  });
  if (!create.ok) {
    const t = await create.text();
    return { action: 'error', detail: `${create.status} ${t.slice(0, 80)}` };
  }
  return { action: 'created', detail: name };
}

async function ensureSitesTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS sites (
      slug TEXT PRIMARY KEY,
      cliente TEXT NOT NULL,
      tenant_group TEXT NOT NULL,
      ambiente TEXT NOT NULL DEFAULT 'producao',
      tipo TEXT NOT NULL DEFAULT 'a_confirmar',
      stack TEXT NOT NULL DEFAULT 'a_confirmar',
      connector_id TEXT,
      subnets_json TEXT NOT NULL DEFAULT '[]',
      stack_meta_json TEXT NOT NULL DEFAULT '{}',
      targets_json TEXT NOT NULL DEFAULT '[]',
      warpgate_roles_json TEXT NOT NULL DEFAULT '[]',
      notas TEXT,
      inventariado BOOLEAN NOT NULL DEFAULT FALSE,
      connector_deployed BOOLEAN NOT NULL DEFAULT FALSE,
      smoke_operador BOOLEAN NOT NULL DEFAULT FALSE,
      updated_at TIMESTAMPTZ NOT NULL,
      updated_by TEXT
    );
  `);
}

async function upsertSite(client, row) {
  await client.query(
    `INSERT INTO sites (
      slug, cliente, tenant_group, ambiente, tipo, stack, connector_id,
      subnets_json, stack_meta_json, targets_json, warpgate_roles_json, notas,
      inventariado, connector_deployed, smoke_operador, updated_at, updated_by
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17
    )
    ON CONFLICT (slug) DO UPDATE SET
      cliente=EXCLUDED.cliente,
      tenant_group=EXCLUDED.tenant_group,
      stack_meta_json=EXCLUDED.stack_meta_json,
      warpgate_roles_json=EXCLUDED.warpgate_roles_json,
      notas=EXCLUDED.notas,
      updated_at=EXCLUDED.updated_at,
      updated_by=EXCLUDED.updated_by
    `,
    [
      row.slug,
      row.cliente,
      row.tenant_group,
      row.ambiente,
      row.tipo,
      row.stack,
      row.connector_id,
      row.subnets_json,
      row.stack_meta_json,
      row.targets_json,
      row.warpgate_roles_json,
      row.notas,
      false,
      false,
      false,
      new Date().toISOString(),
      'sync-cli',
    ],
  );
}

const token = await axisToken();
const props = await listProprietarios(token);
console.log(`Axis proprietarios: ${props.length}`);

const pool = new pg.Pool({ connectionString: DB, max: 2 });
const client = await pool.connect();
try {
  await ensureSitesTable(client);
  let wgCookie = null;
  try {
    wgCookie = await warpgateLogin();
  } catch (e) {
    console.warn('Warpgate login failed:', e.message);
  }

  let created = 0;
  let updated = 0;
  for (const p of props) {
    const id = String(p.id || p.id_proprietario || '');
    const descricao = String(p.descricao || '');
    const code = p.code || p.cd_proprietario || '';
    const slug = siteSlug(code, descricao, id);
    if (!slug) continue;
    const tenant_group = `tenant_${slug}`;
    const role = `tenant-${slug.replace(/_/g, '-')}`;
    const status =
      typeof p.status === 'string'
        ? p.status
        : p.status?.name || '';
    const admin = p.adminEmail || p.admin_email || '';
    const cnpj = p.cnpj || '';

    const exists = await client.query('SELECT 1 FROM sites WHERE slug=$1', [slug]);
    if (exists.rowCount) updated++;
    else created++;

    const meta = {
      mentors_axis_id: id,
      mentors_axis_code: String(code || ''),
      mentors_axis_status: status,
      ...(cnpj ? { cnpj: String(cnpj) } : {}),
      ...(admin ? { admin_email: String(admin) } : {}),
    };

    await upsertSite(client, {
      slug,
      cliente: descricao || slug,
      tenant_group,
      ambiente: 'producao',
      tipo: 'a_confirmar',
      stack: 'a_confirmar',
      connector_id: `connector-${slug}`,
      subnets_json: '[]',
      stack_meta_json: JSON.stringify(meta),
      targets_json: '[]',
      warpgate_roles_json: JSON.stringify([role]),
      notas: [
        'Sincronizado via sync-tenants-cli (Axis).',
        cnpj ? `CNPJ: ${cnpj}` : '',
        admin ? `Admin Axis: ${admin}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
    });

    const kg = await ensureKanidmGroup(
      tenant_group,
      `ArchGate tenant for ${descricao || slug}`,
    );
    const wr = await ensureWarpgateRole(
      wgCookie,
      role,
      `ArchGate tenant role for ${descricao || slug}`,
    );
    console.log(
      `  ${slug}: site=${exists.rowCount ? 'upd' : 'new'} kanidm=${kg.action} wg=${wr.action}`,
    );
  }

  const count = await client.query('SELECT count(*)::int AS n FROM sites');
  console.log(
    `OK: created=${created} updated=${updated} sites_total=${count.rows[0].n}`,
  );
} finally {
  client.release();
  await pool.end();
}
NODE

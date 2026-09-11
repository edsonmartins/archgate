import { beforeEach, describe, expect, it, vi } from 'vitest'

const f = vi.hoisted(() => ({
  add: vi.fn(), disable: vi.fn(), bind: vi.fn(), close: vi.fn(),
  session: { isAuthenticated: true, groups: ['archguard_tenant_admins', 'tenant_rio_quality'], permissions: [], user: { name: 'rio-admin', email: 'rio-admin@example.test' } },
}))
vi.mock('@tanstack/react-start', () => ({ createServerFn: () => {
  let validator: (x: unknown) => unknown = x => x
  const chain = { inputValidator: (v: typeof validator) => { validator = v; return chain }, handler: (h: any) => (arg: any) => h({ data: validator(arg.data) }) }
  return chain
} }))
vi.mock('@/server/session-guard', async importOriginal => ({
  ...await importOriginal<object>(), requireSession: () => f.session,
}))
vi.mock('@/server/activity-log', () => ({ recordActivity: vi.fn() }))
vi.mock('@/server/logger', () => ({ logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() } }))
vi.mock('@/server/idp', () => ({ addUserToGroup: f.add, disableUser: f.disable }))
vi.mock('@/server/http-integration-client', () => ({ integrationFetch: vi.fn(async () => new Response(JSON.stringify({ status: 'ok', steps: [] }))) }))
vi.mock('@/server/warpgate-proxy', () => ({ warpgateConfigured: () => true, bindWarpgateUserRole: f.bind, deleteWarpgateUserByName: vi.fn(async () => ({ ok: true })), rolesForWarpgateTarget: vi.fn() }))
vi.mock('@/server/org-checkouts', () => ({ forceCloseCheckoutsForPrincipal: vi.fn(() => 0) }))
vi.mock('@/server/openfga', () => ({ deleteOpenFgaGrantsForUser: vi.fn(async () => 0), openFgaEnabled: () => false, writeOpenFgaGrant: vi.fn(), openFgaConnectionObject: vi.fn() }))

import { provisionPersonAccessFn, grantPersonTargetFn } from '@/server/lifecycle-fn'
import { revokePersonAccessFn } from '@/server/offboarding-fn'

describe('Audit reproduction — actual handlers, mocked external services', () => {
  beforeEach(() => { vi.clearAllMocks(); f.add.mockResolvedValue({ ok: true }); f.disable.mockResolvedValue({ ok: true }); f.bind.mockResolvedValue({ ok: true }) })
  it('tenant admin can request a platform-admin group for himself', async () => {
    const result = await provisionPersonAccessFn({ data: { username: 'rio-admin', tenant_slug: 'grupo_marra', groups: ['archguard_super_admins'] } })
    expect(f.add).toHaveBeenCalledWith('rio-admin', 'archguard_super_admins')
    expect(f.add).toHaveBeenCalledWith('rio-admin', 'tenant_grupo_marra')
    expect(result.ok).toBe(false) // The side effects succeed but the old component label hides success.
  })
  it('successful IdP disable is reported as failed', async () => {
    const result = await revokePersonAccessFn({ data: { username: 'marra-user', direct_only: true } })
    expect(f.disable).toHaveBeenCalledWith('marra-user')
    expect(result.steps.find((s: any) => s.component === 'idp')?.ok).toBe(true)
    expect(result.all_ok).toBe(true)
    expect(result.ok).toBe(false)
  })
  it('tenant admin grants an explicit role of another tenant; TTL is not passed to the actual binding', async () => {
    const result = await grantPersonTargetFn({ data: { username: 'rio-admin', target: 'marra-db', role: 'tenant-grupo-marra', ttl: '1s' } })
    expect(f.bind).toHaveBeenCalledWith('rio-admin', 'tenant-grupo-marra')
    expect(result.ok).toBe(true)
  })
})

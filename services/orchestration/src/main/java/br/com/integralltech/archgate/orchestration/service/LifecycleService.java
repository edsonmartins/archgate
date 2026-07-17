package br.com.integralltech.archgate.orchestration.service;

import br.com.integralltech.archgate.orchestration.adapter.ComponentAdapter;
import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * W4-ORCH core: provision / grant / revoke multi-component (idempotent).
 * Constructed via OrchestrationConfig (mock adapters) until live clients land.
 */
public class LifecycleService {

  private final List<ComponentAdapter> adapters;
  private final Map<String, OrchestrationResult> lastByUser = new ConcurrentHashMap<>();
  private volatile OrchestrationResult lastGlobal;

  public LifecycleService(List<ComponentAdapter> adapters) {
    this.adapters = adapters;
  }

  public OrchestrationResult provision(
      String tenantSlug,
      String username,
      String email,
      String profile,
      List<String> groups
  ) {
    String opId = UUID.randomUUID().toString();
    List<String> steps = new ArrayList<>();
    List<String> effectiveGroups = new ArrayList<>(groups != null ? groups : List.of());
    String tenantGroup = tenantSlug.startsWith("tenant_") ? tenantSlug : "tenant_" + tenantSlug;
    if (!effectiveGroups.contains(tenantGroup)) {
      effectiveGroups.add(tenantGroup);
    }
    if (!effectiveGroups.contains("archguard_users")) {
      effectiveGroups.add("archguard_users");
    }

    for (ComponentAdapter a : adapters) {
      a.ensurePerson(username, email, effectiveGroups);
      steps.add(a.name() + ":ensurePerson");
    }

    Map<String, String> details = new LinkedHashMap<>();
    details.put("username", username);
    details.put("email", email != null ? email : "");
    details.put("profile", profile != null ? profile : "operator");
    details.put("tenant", tenantSlug);
    details.put("groups", String.join(",", effectiveGroups));

    OrchestrationResult r = OrchestrationResult.ok(opId, "users.provision", steps, details);
    lastByUser.put(username, r);
    lastGlobal = r;
    return r;
  }

  public OrchestrationResult grant(String username, String target, String ttl) {
    String opId = UUID.randomUUID().toString();
    List<String> steps = new ArrayList<>();
    for (ComponentAdapter a : adapters) {
      // Only warpgate (+ openbao policy) typically grant target; mock all for visibility
      if ("warpgate".equals(a.name()) || "openbao".equals(a.name()) || "mock-all".equals(a.name())) {
        a.grantAccess(username, target, ttl != null ? ttl : "8h");
        steps.add(a.name() + ":grantAccess");
      }
    }
    Map<String, String> details = Map.of(
        "username", username,
        "target", target,
        "ttl", ttl != null ? ttl : "8h"
    );
    OrchestrationResult r = OrchestrationResult.ok(opId, "access.grant", steps, details);
    lastByUser.put(username, r);
    lastGlobal = r;
    return r;
  }

  /**
   * Offboarding one-shot: expire IdP, drop grants, revoke leases (W4-ORCH04).
   * Idempotent — second call returns noop if already clean in mock, still ok in live.
   */
  public OrchestrationResult revoke(String username, String reason) {
    String opId = UUID.randomUUID().toString();
    List<String> steps = new ArrayList<>();
    for (ComponentAdapter a : adapters) {
      a.revokeAll(username);
      steps.add(a.name() + ":revokeAll");
    }
    Map<String, String> details = new LinkedHashMap<>();
    details.put("username", username);
    details.put("reason", reason != null ? reason : "offboarding");

    OrchestrationResult r = OrchestrationResult.ok(opId, "users.revoke", steps, details);
    lastByUser.put(username, r);
    lastGlobal = r;
    return r;
  }

  public OrchestrationResult syncTenants() {
    String opId = UUID.randomUUID().toString();
    List<String> steps = List.of("axis:fetch", "kanidm:tenant_groups", "sot:sites");
    OrchestrationResult r = OrchestrationResult.ok(
        opId,
        "tenants.sync",
        steps,
        Map.of("note", "Delegates to existing sync-tenants path in live mode")
    );
    lastGlobal = r;
    return r;
  }

  public OrchestrationResult lastFor(String username) {
    return lastByUser.get(username);
  }

  public OrchestrationResult lastGlobal() {
    return lastGlobal;
  }
}

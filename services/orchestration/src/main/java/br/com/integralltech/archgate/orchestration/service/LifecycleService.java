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
  private final OperationRepository operationRepository;
  private volatile OrchestrationResult lastGlobal;

  public LifecycleService(List<ComponentAdapter> adapters) {
    this(adapters, new InMemoryOperationRepository());
  }

  public LifecycleService(List<ComponentAdapter> adapters, OperationRepository operationRepository) {
    this.adapters = adapters;
    this.operationRepository = operationRepository;
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

    List<String> errors = new ArrayList<>();
    for (ComponentAdapter a : adapters) {
      try {
        a.ensurePerson(username, email, effectiveGroups);
        steps.add(a.name() + ":ensurePerson");
      } catch (RuntimeException e) {
        steps.add(a.name() + ":ensurePerson:FAIL");
        errors.add(a.name() + ": " + e.getMessage());
      }
    }

    Map<String, String> details = new LinkedHashMap<>();
    details.put("username", username);
    details.put("email", email != null ? email : "");
    details.put("profile", profile != null ? profile : "operator");
    details.put("tenant", tenantSlug);
    details.put("groups", String.join(",", effectiveGroups));
    if (!errors.isEmpty()) {
      details.put("errors", String.join(" | ", errors));
    }

    OrchestrationResult r = errors.isEmpty()
        ? OrchestrationResult.ok(opId, "users.provision", steps, details)
        : OrchestrationResult.partial(opId, "users.provision", steps, details);
    return record(username, r);
  }

  public OrchestrationResult grant(String username, String target, String ttl) {
    String opId = UUID.randomUUID().toString();
    List<String> steps = new ArrayList<>();
    List<String> errors = new ArrayList<>();
    for (ComponentAdapter a : adapters) {
      // Only warpgate (+ openbao policy) typically grant target; mock all for visibility
      if ("warpgate".equals(a.name()) || "openbao".equals(a.name()) || "mock-all".equals(a.name())) {
        try {
          a.grantAccess(username, target, ttl != null ? ttl : "8h");
          steps.add(a.name() + ":grantAccess");
        } catch (RuntimeException e) {
          steps.add(a.name() + ":grantAccess:FAIL");
          errors.add(a.name() + ": " + e.getMessage());
        }
      }
    }
    Map<String, String> details = new LinkedHashMap<>();
    details.put("username", username);
    details.put("target", target);
    details.put("ttl", ttl != null ? ttl : "8h");
    if (!errors.isEmpty()) {
      details.put("errors", String.join(" | ", errors));
    }
    OrchestrationResult r = errors.isEmpty()
        ? OrchestrationResult.ok(opId, "access.grant", steps, details)
        : OrchestrationResult.partial(opId, "access.grant", steps, details);
    return record(username, r);
  }

  /**
   * Offboarding one-shot: expire IdP, drop grants, revoke leases (W4-ORCH04).
   * Idempotent — second call returns noop if already clean in mock, still ok in live.
   * Continues across adapters even if one fails (best-effort revoke).
   */
  public OrchestrationResult revoke(String username, String reason) {
    return revoke(username, null, reason);
  }

  public OrchestrationResult revoke(String username, String membershipId, String reason) {
    String opId = UUID.randomUUID().toString();
    List<String> steps = new ArrayList<>();
    List<String> errors = new ArrayList<>();
    for (ComponentAdapter a : adapters) {
      try {
        if (membershipId != null && !membershipId.isBlank() && "archguard".equals(a.name())) {
          a.revokeMembership(membershipId);
          steps.add(a.name() + ":revokeMembership");
        } else {
          a.revokeAll(username);
          steps.add(a.name() + ":revokeAll");
        }
      } catch (RuntimeException e) {
        steps.add(a.name() + ":revokeAll:FAIL");
        errors.add(a.name() + ": " + e.getMessage());
      }
    }
    Map<String, String> details = new LinkedHashMap<>();
    details.put("username", username);
    if (membershipId != null && !membershipId.isBlank()) {
      details.put("membership_id", membershipId);
    }
    details.put("reason", reason != null ? reason : "offboarding");
    if (!errors.isEmpty()) {
      details.put("errors", String.join(" | ", errors));
    }

    OrchestrationResult r = errors.isEmpty()
        ? OrchestrationResult.ok(opId, "users.revoke", steps, details)
        : OrchestrationResult.partial(opId, "users.revoke", steps, details);
    return record(username, r);
  }

  public OrchestrationResult syncTenants() {
    String opId = UUID.randomUUID().toString();
    List<String> steps = List.of("axis:fetch", "archguard:tenant_memberships", "sot:sites");
    OrchestrationResult r = OrchestrationResult.ok(
        opId,
        "tenants.sync",
        steps,
        Map.of("note", "Delegates to existing sync-tenants path in live mode")
    );
    return record(null, r);
  }

  public OrchestrationResult lastFor(String username) {
    return lastByUser.get(username);
  }

  public OrchestrationResult lastGlobal() {
    return lastGlobal;
  }

  public OrchestrationResult byOperation(String operationId) {
    return operationRepository.find(operationId);
  }

  public List<OrchestrationResult> recentOperations(int limit) {
    return operationRepository.recent(limit);
  }

  public List<String> adapterNames() {
    return adapters.stream().map(ComponentAdapter::name).toList();
  }

  private OrchestrationResult record(String username, OrchestrationResult result) {
    operationRepository.save(result);
    if (username != null) {
      lastByUser.put(username, result);
    }
    lastGlobal = result;
    return result;
  }
}

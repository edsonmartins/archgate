package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * ArchGuard identity lifecycle through its versioned control-plane API.
 * Authentication is a short-lived ArchGuard service-account bearer token.
 */
public class ArchGuardLiveAdapter extends HttpLiveAdapter {

  private record SessionContextRequest(String subject) {}

  public ArchGuardLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "archguard";
  }

  /**
   * Resolves an already-authenticated OIDC subject through ArchGuard's narrow
   * service-to-service contract. The bearer is the configured ORCH_ARCHGUARD_TOKEN;
   * no user token or email is sent to this endpoint.
   */
  public ArchGuardSessionContext resolveSessionContext(String subject) {
    if (subject == null || subject.isBlank()) {
      throw new IllegalArgumentException("ArchGuard subject must not be blank");
    }
    ArchGuardSessionContext response = postJson(
        "/api/v1/service/session-context",
        new SessionContextRequest(subject.trim()),
        ArchGuardSessionContext.class);
    if (response == null) {
      throw new IllegalStateException("ArchGuard session-context unavailable in dry-run");
    }
    return response;
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    postJson("/api/v1/identities/upsert", Map.of(
        "username", username,
        "email", email,
        "groups", groups == null ? List.of() : groups));
  }

  @Override
  public void revokeAll(String username) {
    postJson("/api/v1/identities/" + encode(username) + "/revoke", Map.of(
        "reason", "archgate lifecycle offboarding"));
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    // Fine-grained grants belong to the policy/control plane, not to AuthN.
    log.debug("[{}] grantAccess delegated to the policy plane for {} → {}", name(), username, target);
  }

  private static String encode(String value) {
    return java.net.URLEncoder.encode(value, java.nio.charset.StandardCharsets.UTF_8)
        .replace("+", "%20");
  }
}

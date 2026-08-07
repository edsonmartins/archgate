package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * ArchGuard identity lifecycle through its versioned control-plane API.
 * Authentication is a short-lived ArchGuard service-account bearer token.
 */
public class ArchGuardLiveAdapter extends HttpLiveAdapter {

  public ArchGuardLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "archguard";
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

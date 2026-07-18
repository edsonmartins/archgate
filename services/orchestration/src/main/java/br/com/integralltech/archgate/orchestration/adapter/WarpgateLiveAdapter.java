package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * Live Warpgate admin API — user ensure / role bind / revoke.
 * Paths follow Warpgate admin API (v0.12+ style). Adjust ORCH_WG_URL to include
 * origin only; paths below are absolute from that base.
 *
 * <p>Note: exact JSON shape varies by Warpgate version; dry-run remains default.
 * Set ORCH_DRY_RUN=false + ORCH_WG_ENABLED=true after validating against your build.
 */
public class WarpgateLiveAdapter extends HttpLiveAdapter {

  public WarpgateLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "warpgate";
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    // Upsert user; Warpgate uses POST /@warpgate/admin/api/users
    postJson("/@warpgate/admin/api/users", Map.of(
        "username", username,
        "credential_policy", Map.of(),
        "description", email != null ? email : "",
        "roles", groups != null ? groups : List.of()
    ));
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    // Bind user to role that already includes the target (role name ≈ target or shared role).
    // Prefer role membership over inventing bind endpoints that don't exist.
    String role = target != null && !target.isBlank() ? target : "default";
    postJson("/@warpgate/admin/api/roles/" + encode(role) + "/users", Map.of(
        "username", username,
        "ttl", ttl != null ? ttl : "8h"
    ));
  }

  @Override
  public void revokeAll(String username) {
    // Prefer soft-disable if available; hard delete as offboarding fallback.
    try {
      delete("/@warpgate/admin/api/users/" + encode(username));
    } catch (OrchestrationHttpException e) {
      // Some builds use query form
      if (e.status == 404 || e.status == 405) {
        postJson("/@warpgate/admin/api/users/" + encode(username) + "/tickets/close-all", Map.of());
        return;
      }
      throw e;
    }
  }

  private static String encode(String s) {
    return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8)
        .replace("+", "%20");
  }
}

package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * Live Warpgate admin API — roles/targets binding.
 * Exact paths depend on Warpgate admin API version; dry-run safe by default.
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
    postJson("/@warpgate/admin/api/users", Map.of(
        "username", username,
        "email", email != null ? email : "",
        "roles", groups != null ? groups : List.of()
    ));
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    postJson("/@warpgate/admin/api/roles/bind", Map.of(
        "username", username,
        "target", target,
        "ttl", ttl != null ? ttl : "8h"
    ));
  }

  @Override
  public void revokeAll(String username) {
    delete("/@warpgate/admin/api/users/" + encode(username));
  }

  private static String encode(String s) {
    return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8)
        .replace("+", "%20");
  }
}

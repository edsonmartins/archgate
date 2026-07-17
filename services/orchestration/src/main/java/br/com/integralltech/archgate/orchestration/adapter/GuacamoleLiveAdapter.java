package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * Live Guacamole user provision via REST/JDBC bridge used by provision-kanidm-users.
 * Prefer console BFF path in production; this is the Axis one-shot surface.
 */
public class GuacamoleLiveAdapter extends HttpLiveAdapter {

  public GuacamoleLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "guacamole";
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    postJson("/api/session/data/postgresql/users", Map.of(
        "username", username,
        "attributes", Map.of("guac-email-address", email != null ? email : "")
    ));
  }

  @Override
  public void revokeAll(String username) {
    delete("/api/session/data/postgresql/users/" + encode(username));
  }

  private static String encode(String s) {
    return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8)
        .replace("+", "%20");
  }
}

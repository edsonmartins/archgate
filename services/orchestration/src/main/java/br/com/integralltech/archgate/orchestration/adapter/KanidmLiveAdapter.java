package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * Live Kanidm person lifecycle via REST (service account token).
 * Paths aligned with lab offboarding-e2e patterns; adjust when SA API stabilizes.
 */
public class KanidmLiveAdapter extends HttpLiveAdapter {

  public KanidmLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "kanidm";
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    // Create/update person + group memberships (idempotent upsert intent)
    postJson("/v1/person/" + encode(username), personBody(username, email, groups));
    if (groups != null) {
      for (String g : groups) {
        postJson("/v1/group/" + encode(g) + "/_attr/member",
            Map.of("values", List.of(username)));
      }
    }
  }

  @Override
  public void revokeAll(String username) {
    // Expire / disable account — preferred over hard delete for audit trail
    postJson("/v1/person/" + encode(username) + "/_attr/account_expire",
        Map.of("values", List.of("1970-01-01T00:00:00+00:00")));
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    // Target grants live on Warpgate; optional group for target access
    log.debug("[{}] grantAccess delegated to warpgate for {} → {}", name(), username, target);
  }

  private static String encode(String s) {
    return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8)
        .replace("+", "%20");
  }
}

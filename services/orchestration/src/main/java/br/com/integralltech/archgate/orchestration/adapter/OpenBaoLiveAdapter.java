package br.com.integralltech.archgate.orchestration.adapter;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;

import java.util.List;
import java.util.Map;

/**
 * OpenBao lease/policy side-effects for ephemeral DB/SSH access.
 */
public class OpenBaoLiveAdapter extends HttpLiveAdapter {

  public OpenBaoLiveAdapter(OrchestrationProperties.Endpoint endpoint, boolean dryRun) {
    super(endpoint, dryRun);
  }

  @Override
  public String name() {
    return "openbao";
  }

  @Override
  public void ensurePerson(String username, String email, List<String> groups) {
    // No person entity in OpenBao — identity via entity alias optional later
  }

  @Override
  public void grantAccess(String username, String target, String ttl) {
    postJson("/v1/sys/policies/acl/archgate-" + encode(username), Map.of(
        "policy", "path \"database/creds/*\" { capabilities = [\"read\"] }\n"
            + "# target=" + target + " ttl=" + (ttl != null ? ttl : "8h")
    ));
  }

  @Override
  public void revokeAll(String username) {
    // Revoke leases by metadata prefix / tidy — lab uses broker scripts today
    postJson("/v1/sys/leases/revoke-prefix", Map.of(
        "prefix", "database/creds/",
        "sync", true,
        "username_hint", username
    ));
    delete("/v1/sys/policies/acl/archgate-" + encode(username));
  }

  private static String encode(String s) {
    return s.replaceAll("[^a-zA-Z0-9._-]", "_");
  }
}

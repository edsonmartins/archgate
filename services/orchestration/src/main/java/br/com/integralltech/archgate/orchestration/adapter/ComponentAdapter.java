package br.com.integralltech.archgate.orchestration.adapter;

import java.util.List;

/**
 * Side-effect surface for one platform component.
 * Live implementations will call Kanidm REST, Warpgate admin API, Guacamole JDBC, OpenBao.
 */
public interface ComponentAdapter {

  String name();

  /** Ensure person exists with groups; idempotent. */
  void ensurePerson(String username, String email, List<String> groups);

  /** Bind username to target (role/target) with optional TTL hint. */
  void grantAccess(String username, String target, String ttl);

  /** Full revoke for username; safe to re-run (idempotent). */
  void revokeAll(String username);

  /** Soft expire / disable identity only (if partial revoke needed). */
  void expirePerson(String username);
}

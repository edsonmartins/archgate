package br.com.integralltech.archgate.oracleproxy.service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Orchestrates OpenBao-style statement execution against Oracle (or mock recorder).
 */
@Service
public class OracleUserService {

  private static final Logger log = LoggerFactory.getLogger(OracleUserService.class);
  private static final int ORACLE_ID_MAX = 30;

  private final StatementExecutor executor;
  private final Map<String, String> mockUsers = new ConcurrentHashMap<>();

  public OracleUserService(StatementExecutor executor) {
    this.executor = executor;
    log.info("oracle-proxy executor={}", executor.getClass().getSimpleName());
  }

  public void createUser(
      String username, String password, String expiration, Map<String, String> statements) {
    validateUsername(username);
    List<String> sql =
        StatementRenderer.collect(statements, "creation_statements", "create", "sql");
    if (sql.isEmpty()) {
      sql =
          List.of(
              "CREATE USER {{username}} IDENTIFIED BY \"{{password}}\"",
              "GRANT CREATE SESSION TO {{username}}");
    }
    List<String> rendered =
        sql.stream()
            .map(s -> StatementRenderer.render(s, username, password, expiration))
            .toList();
    executor.execute(rendered);
    mockUsers.put(username, password);
    log.info("createUser user={} statements={}", username, rendered.size());
  }

  public void updateUser(
      String username, String password, String expiration, Map<String, String> statements) {
    validateUsername(username);
    List<String> sql =
        StatementRenderer.collect(statements, "renewal_statements", "rollback_statements", "sql");
    if (sql.isEmpty() && password != null && !password.isBlank()) {
      sql = List.of("ALTER USER {{username}} IDENTIFIED BY \"{{password}}\"");
    }
    List<String> rendered =
        sql.stream()
            .map(s -> StatementRenderer.render(s, username, password, expiration))
            .toList();
    if (!rendered.isEmpty()) {
      executor.execute(rendered);
    }
    if (password != null) {
      mockUsers.put(username, password);
    }
    log.info("updateUser user={}", username);
  }

  public void deleteUser(String username, Map<String, String> statements) {
    validateUsername(username);
    List<String> sql =
        StatementRenderer.collect(statements, "revocation_statements", "revoke", "sql");
    if (sql.isEmpty()) {
      sql = List.of("DROP USER {{username}} CASCADE");
    }
    List<String> rendered =
        sql.stream().map(s -> StatementRenderer.render(s, username, null, null)).toList();
    executor.execute(rendered);
    mockUsers.remove(username);
    log.info("deleteUser user={}", username);
  }

  public void rotateRoot(String password) {
    List<String> sql =
        List.of("ALTER USER {{username}} IDENTIFIED BY \"{{password}}\"");
    // root rotation: username is admin — caller should pass via statements; default log only
    List<String> rendered =
        sql.stream().map(s -> StatementRenderer.render(s, "ORACLE_ADMIN", password, null)).toList();
    executor.execute(rendered);
    log.info("rotateRoot");
  }

  public boolean mockExists(String username) {
    return mockUsers.containsKey(username);
  }

  private void validateUsername(String username) {
    if (username == null || username.isBlank()) {
      throw new IllegalArgumentException("username required");
    }
    if (username.length() > ORACLE_ID_MAX) {
      throw new IllegalArgumentException(
          "username exceeds Oracle identifier limit (" + ORACLE_ID_MAX + "): " + username.length());
    }
  }
}

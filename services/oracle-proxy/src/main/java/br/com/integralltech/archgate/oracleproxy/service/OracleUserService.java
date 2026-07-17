package br.com.integralltech.archgate.oracleproxy.service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Executes Oracle DDL via JDBC when configured; otherwise mock in-memory mode for CI/lab.
 * Real ojdbc statements: OpenBao role creation_statements with {{username}}/{{password}}.
 */
@Service
public class OracleUserService {

  private static final Logger log = LoggerFactory.getLogger(OracleUserService.class);
  private static final int ORACLE_ID_MAX = 30; // pre-12c / conservative limit

  private final boolean mockMode;
  private final Map<String, String> mockUsers = new ConcurrentHashMap<>();

  public OracleUserService(@Value("${oracle.proxy.mock:true}") boolean mockMode) {
    this.mockMode = mockMode;
    log.info("oracle-proxy mockMode={}", mockMode);
  }

  public void createUser(
      String username, String password, String expiration, Map<String, String> statements) {
    validateUsername(username);
    if (mockMode) {
      mockUsers.put(username, password);
      log.info("MOCK createUser user={} exp={}", username, expiration);
      return;
    }
    // TODO(W3-ORACLE1.4): execute statements via ojdbc (CREATE USER / GRANT)
    throw new UnsupportedOperationException("JDBC mode not wired yet — set oracle.proxy.mock=true");
  }

  public void updateUser(
      String username, String password, String expiration, Map<String, String> statements) {
    validateUsername(username);
    if (mockMode) {
      if (password != null) {
        mockUsers.put(username, password);
      }
      log.info("MOCK updateUser user={}", username);
      return;
    }
    throw new UnsupportedOperationException("JDBC mode not wired yet");
  }

  public void deleteUser(String username, Map<String, String> statements) {
    validateUsername(username);
    if (mockMode) {
      mockUsers.remove(username);
      log.info("MOCK deleteUser user={}", username);
      return;
    }
    throw new UnsupportedOperationException("JDBC mode not wired yet");
  }

  public void rotateRoot(String password) {
    if (mockMode) {
      log.info("MOCK rotateRoot");
      return;
    }
    throw new UnsupportedOperationException("JDBC mode not wired yet");
  }

  /** Test/helper for mock mode. */
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

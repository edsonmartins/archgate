package br.com.integralltech.archgate.oracleproxy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.integralltech.archgate.oracleproxy.service.OracleUserService;
import br.com.integralltech.archgate.oracleproxy.service.RecordingStatementExecutor;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class OracleUserServiceMockTest {

  private RecordingStatementExecutor exec;
  private OracleUserService users;

  @BeforeEach
  void setUp() {
    exec = new RecordingStatementExecutor();
    users = new OracleUserService(exec);
  }

  @Test
  void createRendersDefaultStatements() {
    users.createUser("v_u1", "P@ss1", null, null);
    assertTrue(users.mockExists("v_u1"));
    assertEquals(2, exec.history().size());
    assertTrue(exec.history().get(0).contains("CREATE USER v_u1"));
    assertTrue(exec.history().get(0).contains("P@ss1"));
  }

  @Test
  void deleteUsesDropCascade() {
    users.createUser("v_u2", "x", null, Map.of());
    exec.clear();
    users.deleteUser("v_u2", null);
    assertFalse(users.mockExists("v_u2"));
    assertTrue(exec.history().get(0).contains("DROP USER v_u2 CASCADE"));
  }

  @Test
  void customCreationStatements() {
    users.createUser(
        "v_u3",
        "pw",
        null,
        Map.of("creation_statements", "CREATE USER {{username}} IDENTIFIED BY \"{{password}}\""));
    assertEquals(1, exec.history().size());
  }
}

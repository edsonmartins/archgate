package br.com.integralltech.archgate.oracleproxy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.integralltech.archgate.oracleproxy.service.StatementRenderer;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class StatementRendererTest {

  @Test
  void substitutesVaultStylePlaceholders() {
    String sql =
        StatementRenderer.render(
            "CREATE USER {{username}} IDENTIFIED BY \"{{password}}\"",
            "v_abc",
            "S3cret!",
            "2026-01-01");
    assertEquals("CREATE USER v_abc IDENTIFIED BY \"S3cret!\"", sql);
  }

  @Test
  void collectsSemicolonSeparated() {
    List<String> parts =
        StatementRenderer.collect(
            Map.of("creation_statements", "CREATE USER {{username}}; GRANT CREATE SESSION TO {{username}}"),
            "creation_statements");
    assertEquals(2, parts.size());
    assertTrue(parts.get(0).startsWith("CREATE USER"));
  }
}

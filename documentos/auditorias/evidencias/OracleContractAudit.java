import java.util.LinkedHashMap;
import br.com.integralltech.archgate.oracleproxy.service.StatementRenderer;
public class OracleContractAudit {
  public static void main(String[] args) {
    var statements = new LinkedHashMap<String, String>();
    statements.put("cmd_0", "CREATE USER {{username}} IDENTIFIED BY \"{{password}}\"");
    statements.put("cmd_1", "GRANT CREATE SESSION TO {{username}}");
    statements.put("creation", statements.get("cmd_0"));
    statements.put("revocation", statements.get("cmd_1"));
    var result = StatementRenderer.collect(statements, "creation_statements", "create", "sql");
    System.out.println("plugin commands=2; Java execution statements=" + result.size());
    if (result.size() != 4) throw new AssertionError("Unexpected reproduction result");
    System.out.println("DUPLICATION_REPRODUCED");
  }
}

package br.com.integralltech.archgate.oracleproxy.service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Executes DDL against Oracle via JDBC thin (ojdbc on classpath when mock=false).
 * Driver: oracle.jdbc.OracleDriver
 */
@Component
@ConditionalOnProperty(name = "oracle.proxy.mock", havingValue = "false")
public class JdbcStatementExecutor implements StatementExecutor {

  private static final Logger log = LoggerFactory.getLogger(JdbcStatementExecutor.class);

  private final String url;
  private final String user;
  private final String password;

  public JdbcStatementExecutor(
      @Value("${oracle.jdbc.url}") String url,
      @Value("${oracle.jdbc.user}") String user,
      @Value("${oracle.jdbc.password}") String password) {
    this.url = url;
    this.user = user;
    this.password = password;
    try {
      Class.forName("oracle.jdbc.OracleDriver");
    } catch (ClassNotFoundException e) {
      throw new IllegalStateException(
          "ojdbc not on classpath — enable ojdbc11 dependency in pom.xml", e);
    }
  }

  @Override
  public void execute(List<String> sqlStatements) {
    try (Connection conn = DriverManager.getConnection(url, user, password)) {
      conn.setAutoCommit(true);
      try (Statement st = conn.createStatement()) {
        for (String sql : sqlStatements) {
          log.info("JDBC exec: {}", sql.replaceAll("(?i)IDENTIFIED BY\\s+'[^']*'", "IDENTIFIED BY '***'"));
          st.execute(sql);
        }
      }
    } catch (SQLException e) {
      throw new IllegalStateException("Oracle JDBC failed: " + e.getMessage(), e);
    }
  }
}

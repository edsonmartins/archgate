package br.com.integralltech.archgate.oracleproxy.service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Mock executor: records SQL for tests; does not touch Oracle. */
@Component
@ConditionalOnProperty(name = "oracle.proxy.mock", havingValue = "true", matchIfMissing = true)
public class RecordingStatementExecutor implements StatementExecutor {

  private static final Logger log = LoggerFactory.getLogger(RecordingStatementExecutor.class);
  private final List<String> history = Collections.synchronizedList(new ArrayList<>());

  @Override
  public void execute(List<String> sqlStatements) {
    for (String sql : sqlStatements) {
      history.add(sql);
      log.info("MOCK SQL: {}", redactPassword(sql));
    }
  }

  public List<String> history() {
    return List.copyOf(history);
  }

  public void clear() {
    history.clear();
  }

  private static String redactPassword(String sql) {
    return sql.replaceAll("(?i)IDENTIFIED BY\\s+'[^']*'", "IDENTIFIED BY '***'");
  }
}

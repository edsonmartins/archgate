package br.com.integralltech.archgate.oracleproxy.service;

import java.util.List;

public interface StatementExecutor {

  void execute(List<String> sqlStatements);
}

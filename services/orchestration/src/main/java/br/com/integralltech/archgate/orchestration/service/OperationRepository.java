package br.com.integralltech.archgate.orchestration.service;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import java.util.List;

public interface OperationRepository {
  void save(OrchestrationResult result);
  OrchestrationResult find(String operationId);
  List<OrchestrationResult> recent(int limit);
}

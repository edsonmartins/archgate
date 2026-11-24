package br.com.integralltech.archgate.orchestration.service;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import java.util.Map;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!jdbc")
public class InMemoryOperationRepository implements OperationRepository {
  private final Map<String, OrchestrationResult> operations = new ConcurrentHashMap<>();
  public void save(OrchestrationResult result) { operations.put(result.operationId(), result); }
  public OrchestrationResult find(String operationId) {
    return operationId == null ? null : operations.get(operationId);
  }
  public List<OrchestrationResult> recent(int limit) {
    int safeLimit = Math.max(1, Math.min(limit, 1000));
    return operations.values().stream()
        .sorted((left, right) -> right.at().compareTo(left.at()))
        .limit(safeLimit)
        .toList();
  }
}

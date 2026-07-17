package br.com.integralltech.archgate.orchestration.service;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory idempotency for Axis webhooks (W4-ORCH05).
 * Replace with Redis/PG in HA (W5).
 */
@Component
public class IdempotencyStore {

  private final Map<String, OrchestrationResult> byKey = new ConcurrentHashMap<>();

  public Optional<OrchestrationResult> get(String key) {
    if (key == null || key.isBlank()) {
      return Optional.empty();
    }
    return Optional.ofNullable(byKey.get(key));
  }

  public void put(String key, OrchestrationResult result) {
    if (key != null && !key.isBlank()) {
      byKey.put(key, result);
    }
  }
}

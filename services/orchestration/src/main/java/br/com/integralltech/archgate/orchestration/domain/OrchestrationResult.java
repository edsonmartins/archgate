package br.com.integralltech.archgate.orchestration.domain;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public record OrchestrationResult(
    String operationId,
    String operation,
    String status,
    Instant at,
    List<String> steps,
    Map<String, String> details
) {
  public static OrchestrationResult ok(
      String operationId,
      String operation,
      List<String> steps,
      Map<String, String> details
  ) {
    return new OrchestrationResult(operationId, operation, "ok", Instant.now(), steps, details);
  }

  public static OrchestrationResult noop(
      String operationId,
      String operation,
      List<String> steps,
      Map<String, String> details
  ) {
    return new OrchestrationResult(operationId, operation, "noop", Instant.now(), steps, details);
  }

  /** Some adapters succeeded, others failed (best-effort revoke / multi-component). */
  public static OrchestrationResult partial(
      String operationId,
      String operation,
      List<String> steps,
      Map<String, String> details
  ) {
    return new OrchestrationResult(operationId, operation, "partial", Instant.now(), steps, details);
  }
}

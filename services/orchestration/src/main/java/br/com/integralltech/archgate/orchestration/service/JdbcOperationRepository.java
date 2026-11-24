package br.com.integralltech.archgate.orchestration.service;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.sql.Timestamp;

@Repository
@Profile("jdbc")
public class JdbcOperationRepository implements OperationRepository {
  private final JdbcTemplate jdbc;
  private final ObjectMapper mapper;

  public JdbcOperationRepository(JdbcTemplate jdbc, ObjectMapper mapper) {
    this.jdbc = jdbc;
    this.mapper = mapper;
  }

  @Override
  public void save(OrchestrationResult result) {
    jdbc.update("""
        INSERT INTO archgate_operations(operation_id, operation, status, occurred_at, steps, details)
        VALUES (?, ?, ?, ?, ?::jsonb, ?::jsonb)
        ON CONFLICT (operation_id) DO UPDATE SET status=EXCLUDED.status,
          occurred_at=EXCLUDED.occurred_at, steps=EXCLUDED.steps, details=EXCLUDED.details
        """, result.operationId(), result.operation(), result.status(), Timestamp.from(result.at()),
        json(result.steps()), json(result.details()));
  }

  @Override
  public OrchestrationResult find(String operationId) {
    List<OrchestrationResult> rows = jdbc.query("""
        SELECT operation_id, operation, status, occurred_at, steps, details
        FROM archgate_operations WHERE operation_id = ?
        """, (rs, row) -> new OrchestrationResult(
        rs.getString("operation_id"), rs.getString("operation"), rs.getString("status"),
        rs.getTimestamp("occurred_at").toInstant(),
        readList(rs.getString("steps")), readMap(rs.getString("details"))), operationId);
    return rows.isEmpty() ? null : rows.getFirst();
  }

  @Override
  public List<OrchestrationResult> recent(int limit) {
    int safeLimit = Math.max(1, Math.min(limit, 1000));
    return jdbc.query("""
        SELECT operation_id, operation, status, occurred_at, steps, details
        FROM archgate_operations ORDER BY occurred_at DESC LIMIT ?
        """, (rs, row) -> new OrchestrationResult(
        rs.getString("operation_id"), rs.getString("operation"), rs.getString("status"),
        rs.getTimestamp("occurred_at").toInstant(),
        readList(rs.getString("steps")), readMap(rs.getString("details"))), safeLimit);
  }

  private String json(Object value) {
    try { return mapper.writeValueAsString(value); }
    catch (JsonProcessingException e) { throw new IllegalArgumentException("Cannot serialize operation", e); }
  }

  private List<String> readList(String value) {
    try { return mapper.readValue(value, mapper.getTypeFactory().constructCollectionType(List.class, String.class)); }
    catch (JsonProcessingException e) { throw new IllegalStateException("Invalid operation steps", e); }
  }

  private Map<String, String> readMap(String value) {
    try { return mapper.readValue(value, mapper.getTypeFactory().constructMapType(Map.class, String.class, String.class)); }
    catch (JsonProcessingException e) { throw new IllegalStateException("Invalid operation details", e); }
  }
}

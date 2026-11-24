package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.domain.OrchestrationResult;
import br.com.integralltech.archgate.orchestration.service.JdbcOperationRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:postgresql://127.0.0.1:55433/archgate",
    "spring.datasource.username=archgate",
    "spring.datasource.password=archgate_dev",
    "spring.autoconfigure.exclude=",
    "spring.sql.init.mode=always",
    "archgate.orchestration.api-token=test-token"
})
@ActiveProfiles("jdbc")
class JdbcOperationRepositoryIT {

  @Autowired JdbcOperationRepository repository;
  @Autowired JdbcTemplate jdbc;

  @Test
  void persistsAndReadsOperationFromPostgres() {
    String id = "jdbc-test-" + System.nanoTime();
    OrchestrationResult expected = new OrchestrationResult(
        id, "users.provision", "ok", Instant.now(),
        List.of("archguard:ensurePerson"), Map.of("username", "jdbc-user"));

    repository.save(expected);
    OrchestrationResult actual = repository.find(id);

    assertEquals(id, actual.operationId());
    assertEquals(expected.operation(), actual.operation());
    assertEquals(expected.steps(), actual.steps());
    assertEquals("jdbc-user", actual.details().get("username"));
    jdbc.update("DELETE FROM archgate_operations WHERE operation_id = ?", id);
  }
}

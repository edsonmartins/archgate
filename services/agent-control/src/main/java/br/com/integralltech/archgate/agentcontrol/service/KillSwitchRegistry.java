package br.com.integralltech.archgate.agentcontrol.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/** W5-AG06 — in-process kill flag; live path also revokes SA via orchestration. */
@Component
public class KillSwitchRegistry {

  public record KillRecord(String agentId, String reason, String actor, Instant at) {}

  private final Map<String, KillRecord> killed = new ConcurrentHashMap<>();

  public void kill(String agentId, String reason, String actor) {
    killed.put(agentId, new KillRecord(agentId, reason, actor, Instant.now()));
  }

  public void clear(String agentId) {
    killed.remove(agentId);
  }

  public boolean isKilled(String agentId) {
    return killed.containsKey(agentId);
  }

  public Optional<KillRecord> get(String agentId) {
    return Optional.ofNullable(killed.get(agentId));
  }
}

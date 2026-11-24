package br.com.integralltech.archgate.agentcontrol.service;

import br.com.integralltech.archgate.agentcontrol.domain.Models.AuditEvent;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;

/**
 * W5-AG07 — agent → human → action chain (in-memory; export later).
 */
@Component
public class AuditLog {

  private final List<AuditEvent> events = new CopyOnWriteArrayList<>();

  @Value("${archgate.agent.audit.max-events:10000}")
  private int maxEvents = 10000;

  public AuditEvent record(
      String type,
      String agentId,
      String humanApprover,
      String incidentId,
      String target,
      String action,
      String detail,
      Map<String, String> meta
  ) {
    AuditEvent e = new AuditEvent(
        UUID.randomUUID().toString(),
        Instant.now(),
        type,
        agentId,
        humanApprover,
        incidentId,
        target,
        action,
        detail,
        meta != null ? meta : Map.of()
    );
    events.add(e);
    while (events.size() > Math.max(1, maxEvents)) {
      events.remove(0);
    }
    return e;
  }

  public List<AuditEvent> byIncident(String incidentId) {
    return events.stream()
        .filter(e -> incidentId != null && incidentId.equals(e.incidentId()))
        .collect(Collectors.toList());
  }

  public List<AuditEvent> byAgent(String agentId) {
    return events.stream()
        .filter(e -> agentId != null && agentId.equals(e.agentId()))
        .collect(Collectors.toList());
  }

  public List<AuditEvent> all() {
    return new ArrayList<>(events);
  }

  public List<AuditEvent> query(String incidentId, String agentId, String type, int limit) {
    int safeLimit = Math.max(1, Math.min(limit, 1000));
    return events.stream()
        .filter(e -> incidentId == null || incidentId.isBlank() || incidentId.equals(e.incidentId()))
        .filter(e -> agentId == null || agentId.isBlank() || agentId.equals(e.agentId()))
        .filter(e -> type == null || type.isBlank() || type.equals(e.type()))
        .sorted((left, right) -> right.at().compareTo(left.at()))
        .limit(safeLimit)
        .toList();
  }
}

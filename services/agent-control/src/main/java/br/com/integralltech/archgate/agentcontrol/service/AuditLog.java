package br.com.integralltech.archgate.agentcontrol.service;

import br.com.integralltech.archgate.agentcontrol.domain.Models.AuditEvent;
import org.springframework.stereotype.Component;

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
}

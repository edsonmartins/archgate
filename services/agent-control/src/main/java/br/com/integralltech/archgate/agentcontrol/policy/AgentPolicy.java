package br.com.integralltech.archgate.agentcontrol.policy;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Parsed allow-list (YAML). Gateway policy — not LLM judgment.
 */
public class AgentPolicy {

  private String agentId = "sa-opensre";
  private int rateLimitPerMinute = 30;
  private boolean requireIncidentId = true;
  private String maxTtl = "15m";
  private final Set<String> readActions = new LinkedHashSet<>();
  private final Set<String> mutantActions = new LinkedHashSet<>();
  private final Set<String> allowedTargets = new LinkedHashSet<>();
  private final List<String> commandDenylist = new ArrayList<>();
  private final List<String> commandAllowlistPrefixes = new ArrayList<>();

  @SuppressWarnings("unchecked")
  public static AgentPolicy fromMap(Map<String, Object> raw) {
    AgentPolicy p = new AgentPolicy();
    if (raw == null) {
      return p;
    }
    if (raw.get("agent_id") != null) {
      p.agentId = String.valueOf(raw.get("agent_id"));
    }
    Object defaults = raw.get("defaults");
    if (defaults instanceof Map<?, ?> d) {
      Object rl = d.get("rate_limit_per_minute");
      if (rl instanceof Number n) {
        p.rateLimitPerMinute = n.intValue();
      }
      Object req = d.get("require_incident_id");
      if (req instanceof Boolean b) {
        p.requireIncidentId = b;
      }
      if (d.get("max_ttl") != null) {
        p.maxTtl = String.valueOf(d.get("max_ttl"));
      }
    }
    loadActionIds(raw.get("read_actions"), p.readActions);
    loadActionIds(raw.get("mutant_actions"), p.mutantActions);
    Object targets = raw.get("allowed_targets");
    if (targets instanceof List<?> list) {
      for (Object t : list) {
        p.allowedTargets.add(String.valueOf(t));
      }
    }
    Object deny = raw.get("command_denylist");
    if (deny instanceof List<?> list) {
      for (Object t : list) {
        p.commandDenylist.add(String.valueOf(t));
      }
    }
    Object allow = raw.get("command_allowlist_prefixes");
    if (allow instanceof List<?> list) {
      for (Object t : list) {
        p.commandAllowlistPrefixes.add(String.valueOf(t));
      }
    }
    return p;
  }

  @SuppressWarnings("unchecked")
  private static void loadActionIds(Object node, Set<String> out) {
    if (!(node instanceof List<?> list)) {
      return;
    }
    for (Object item : list) {
      if (item instanceof Map<?, ?> m && m.get("id") != null) {
        out.add(String.valueOf(m.get("id")));
      } else if (item != null) {
        out.add(String.valueOf(item));
      }
    }
  }

  public String agentId() {
    return agentId;
  }

  public int rateLimitPerMinute() {
    return rateLimitPerMinute;
  }

  public boolean requireIncidentId() {
    return requireIncidentId;
  }

  public String maxTtl() {
    return maxTtl;
  }

  public boolean isRead(String action) {
    return readActions.contains(action);
  }

  public boolean isMutant(String action) {
    return mutantActions.contains(action);
  }

  public boolean isKnownAction(String action) {
    return isRead(action) || isMutant(action);
  }

  public boolean isTargetAllowed(String target) {
    return allowedTargets.isEmpty() || allowedTargets.contains(target);
  }

  public boolean isCommandDenied(String command) {
    if (command == null || command.isBlank()) {
      return false;
    }
    String c = command.trim();
    for (String d : commandDenylist) {
      if (c.contains(d)) {
        return true;
      }
    }
    if (commandAllowlistPrefixes.isEmpty()) {
      return false;
    }
    for (String p : commandAllowlistPrefixes) {
      if (c.startsWith(p)) {
        return false;
      }
    }
    // mutant shell with allowlist: unknown prefix = deny
    return true;
  }
}

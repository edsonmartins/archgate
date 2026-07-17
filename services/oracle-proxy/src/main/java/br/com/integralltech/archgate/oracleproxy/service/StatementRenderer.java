package br.com.integralltech.archgate.oracleproxy.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * OpenBao-style template substitution for database plugin statements.
 * Supports {{name}}, {{username}}, {{password}}, {{expiration}}.
 */
public final class StatementRenderer {

  private StatementRenderer() {}

  public static String render(String template, String username, String password, String expiration) {
    if (template == null) {
      return "";
    }
    String out = template;
    out = out.replace("{{name}}", nullToEmpty(username));
    out = out.replace("{{username}}", nullToEmpty(username));
    out = out.replace("{{password}}", nullToEmpty(password));
    out = out.replace("{{expiration}}", nullToEmpty(expiration));
    return out;
  }

  /**
   * Collect statements from a map (creation_statements, revocation_statements, …)
   * or semicolon-separated multi-line values.
   */
  public static List<String> collect(Map<String, String> statements, String... preferredKeys) {
    List<String> out = new ArrayList<>();
    if (statements == null || statements.isEmpty()) {
      return out;
    }
    for (String key : preferredKeys) {
      String raw = statements.get(key);
      if (raw != null && !raw.isBlank()) {
        splitAndAdd(raw, out);
      }
    }
    if (out.isEmpty()) {
      // fallback: any value in the map
      for (String raw : statements.values()) {
        splitAndAdd(raw, out);
      }
    }
    return out;
  }

  private static void splitAndAdd(String raw, List<String> out) {
    for (String part : raw.split(";")) {
      String s = part.trim();
      if (!s.isEmpty()) {
        out.add(s);
      }
    }
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}

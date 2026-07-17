package br.com.integralltech.archgate.orchestration.adapter;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Lab/mock adapter — records desired state for tests and smoke without live IdP.
 */
public class MockComponentAdapter implements ComponentAdapter {

  private final String name;
  private final Set<String> people = ConcurrentHashMap.newKeySet();
  private final Map<String, Set<String>> grants = new ConcurrentHashMap<>();
  private final List<String> audit = new ArrayList<>();

  public MockComponentAdapter(String name) {
    this.name = name;
  }

  @Override
  public String name() {
    return name;
  }

  @Override
  public synchronized void ensurePerson(String username, String email, List<String> groups) {
    people.add(username);
    audit.add("ensurePerson:" + username + ":" + String.join(",", groups));
  }

  @Override
  public synchronized void grantAccess(String username, String target, String ttl) {
    grants.computeIfAbsent(username, k -> ConcurrentHashMap.newKeySet()).add(target);
    audit.add("grant:" + username + ":" + target + ":" + ttl);
  }

  @Override
  public synchronized void revokeAll(String username) {
    people.remove(username);
    grants.remove(username);
    audit.add("revokeAll:" + username);
  }

  @Override
  public synchronized void expirePerson(String username) {
    people.remove(username);
    audit.add("expire:" + username);
  }

  public boolean hasPerson(String username) {
    return people.contains(username);
  }

  public boolean hasGrant(String username, String target) {
    Set<String> g = grants.get(username);
    return g != null && g.contains(target);
  }

  public List<String> auditTrail() {
    synchronized (this) {
      return List.copyOf(audit);
    }
  }

  public void reset() {
    people.clear();
    grants.clear();
    synchronized (this) {
      audit.clear();
    }
  }
}

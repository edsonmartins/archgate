package br.com.integralltech.archgate.agentcontrol.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Simple per-agent sliding window (in-memory; HA → Redis). */
@Component
public class RateLimiter {

  private final int maxPerMinute;
  private final Map<String, Deque<Long>> windows = new ConcurrentHashMap<>();

  public RateLimiter(@Value("${archgate.agent.max-requests-per-minute:30}") int maxPerMinute) {
    this.maxPerMinute = maxPerMinute;
  }

  public boolean tryAcquire(String agentId) {
    long now = System.currentTimeMillis();
    long cutoff = now - 60_000L;
    Deque<Long> q = windows.computeIfAbsent(agentId, k -> new ArrayDeque<>());
    synchronized (q) {
      while (!q.isEmpty() && q.peekFirst() < cutoff) {
        q.pollFirst();
      }
      if (q.size() >= maxPerMinute) {
        return false;
      }
      q.addLast(now);
      return true;
    }
  }
}

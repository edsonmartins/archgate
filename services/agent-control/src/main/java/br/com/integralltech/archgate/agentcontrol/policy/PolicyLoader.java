package br.com.integralltech.archgate.agentcontrol.policy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

@Component
public class PolicyLoader {

  private static final Logger log = LoggerFactory.getLogger(PolicyLoader.class);

  @Value("${archgate.agent.policy-path:}")
  private String policyPath;

  private volatile AgentPolicy policy = new AgentPolicy();

  @PostConstruct
  public void load() {
    try {
      if (policyPath != null && !policyPath.isBlank()) {
        Path p = Path.of(policyPath).toAbsolutePath().normalize();
        if (Files.isRegularFile(p)) {
          try (InputStream in = Files.newInputStream(p)) {
            policy = AgentPolicy.fromMap(new Yaml().load(in));
            log.info("Loaded agent policy from {}", p);
            return;
          }
        }
      }
      try (InputStream in = new ClassPathResource("opensre-allowlist-default.yaml").getInputStream()) {
        policy = AgentPolicy.fromMap(new Yaml().load(in));
        log.info("Loaded bundled agent policy default");
      }
    } catch (Exception e) {
      log.warn("Failed to load policy, using empty defaults: {}", e.getMessage());
      policy = new AgentPolicy();
    }
  }

  public AgentPolicy policy() {
    return policy;
  }

  /** Test helper */
  public void replace(AgentPolicy p) {
    this.policy = p;
  }
}

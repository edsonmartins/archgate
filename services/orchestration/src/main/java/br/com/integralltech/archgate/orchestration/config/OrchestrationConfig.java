package br.com.integralltech.archgate.orchestration.config;

import br.com.integralltech.archgate.orchestration.adapter.ComponentAdapter;
import br.com.integralltech.archgate.orchestration.adapter.MockComponentAdapter;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OrchestrationConfig {

  @Bean
  public LifecycleService lifecycleService() {
    // Named adapters mirror production surfaces; all mock until live clients land.
    List<ComponentAdapter> adapters = List.of(
        new MockComponentAdapter("kanidm"),
        new MockComponentAdapter("warpgate"),
        new MockComponentAdapter("guacamole"),
        new MockComponentAdapter("openbao")
    );
    return new LifecycleService(adapters);
  }
}

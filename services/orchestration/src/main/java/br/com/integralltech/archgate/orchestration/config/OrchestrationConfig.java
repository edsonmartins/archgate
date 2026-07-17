package br.com.integralltech.archgate.orchestration.config;

import br.com.integralltech.archgate.orchestration.adapter.ComponentAdapter;
import br.com.integralltech.archgate.orchestration.adapter.GuacamoleLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.KanidmLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.MockComponentAdapter;
import br.com.integralltech.archgate.orchestration.adapter.OpenBaoLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.WarpgateLiveAdapter;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

@Configuration
@EnableConfigurationProperties(OrchestrationProperties.class)
public class OrchestrationConfig {

  @Bean
  public LifecycleService lifecycleService(OrchestrationProperties props) {
    List<ComponentAdapter> adapters = new ArrayList<>();
    if (props.isLive()) {
      boolean dry = props.dryRun();
      adapters.add(new KanidmLiveAdapter(orDisabled(props.kanidm()), dry));
      adapters.add(new WarpgateLiveAdapter(orDisabled(props.warpgate()), dry));
      adapters.add(new GuacamoleLiveAdapter(orDisabled(props.guacamole()), dry));
      adapters.add(new OpenBaoLiveAdapter(orDisabled(props.openbao()), dry));
    } else {
      adapters.add(new MockComponentAdapter("kanidm"));
      adapters.add(new MockComponentAdapter("warpgate"));
      adapters.add(new MockComponentAdapter("guacamole"));
      adapters.add(new MockComponentAdapter("openbao"));
    }
    return new LifecycleService(adapters);
  }

  private static OrchestrationProperties.Endpoint orDisabled(OrchestrationProperties.Endpoint e) {
    if (e == null) {
      return new OrchestrationProperties.Endpoint("", "", false);
    }
    return e;
  }
}

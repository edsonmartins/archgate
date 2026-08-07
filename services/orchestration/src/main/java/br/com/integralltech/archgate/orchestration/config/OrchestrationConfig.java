package br.com.integralltech.archgate.orchestration.config;

import br.com.integralltech.archgate.orchestration.adapter.ComponentAdapter;
import br.com.integralltech.archgate.orchestration.adapter.GuacamoleLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.ArchGuardLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.MockComponentAdapter;
import br.com.integralltech.archgate.orchestration.adapter.OpenBaoLiveAdapter;
import br.com.integralltech.archgate.orchestration.adapter.WarpgateLiveAdapter;
import br.com.integralltech.archgate.orchestration.security.ServiceTokenFilter;
import br.com.integralltech.archgate.orchestration.service.LifecycleService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

import java.util.ArrayList;
import java.util.List;

@Configuration
@EnableConfigurationProperties(OrchestrationProperties.class)
public class OrchestrationConfig {

  private static final Logger log = LoggerFactory.getLogger(OrchestrationConfig.class);

  /**
   * Service-token authentication in front of every orchestration route.
   * Runs first so no controller sees an unauthenticated request.
   */
  @Bean
  public FilterRegistrationBean<ServiceTokenFilter> serviceTokenFilter(
      OrchestrationProperties props) {
    if (!props.hasApiToken()) {
      log.error(
          "archgate.orchestration.api-token (ORCH_API_TOKEN) is unset — "
              + "the API will answer 503 until it is configured");
    }
    FilterRegistrationBean<ServiceTokenFilter> reg = new FilterRegistrationBean<>();
    reg.setFilter(new ServiceTokenFilter(props));
    reg.addUrlPatterns("/*");
    reg.setOrder(Ordered.HIGHEST_PRECEDENCE);
    return reg;
  }

  @Bean
  public LifecycleService lifecycleService(OrchestrationProperties props) {
    List<ComponentAdapter> adapters = new ArrayList<>();
    if (props.isLive()) {
      boolean dry = props.dryRun();
      adapters.add(new ArchGuardLiveAdapter(orDisabled(props.archguard()), dry));
      adapters.add(new WarpgateLiveAdapter(orDisabled(props.warpgate()), dry));
      adapters.add(new GuacamoleLiveAdapter(orDisabled(props.guacamole()), dry));
      adapters.add(new OpenBaoLiveAdapter(orDisabled(props.openbao()), dry));
    } else {
      adapters.add(new MockComponentAdapter("archguard"));
      adapters.add(new MockComponentAdapter("warpgate"));
      adapters.add(new MockComponentAdapter("guacamole"));
      adapters.add(new MockComponentAdapter("openbao"));
    }
    return new LifecycleService(adapters);
  }

  @Bean
  public ArchGuardLiveAdapter archGuardClient(OrchestrationProperties props) {
    return new ArchGuardLiveAdapter(orDisabled(props.archguard()), false);
  }

  private static OrchestrationProperties.Endpoint orDisabled(OrchestrationProperties.Endpoint e) {
    if (e == null) {
      return new OrchestrationProperties.Endpoint("", "", false);
    }
    return e;
  }
}

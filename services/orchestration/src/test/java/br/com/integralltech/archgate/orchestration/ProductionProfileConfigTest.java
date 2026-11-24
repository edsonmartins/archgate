package br.com.integralltech.archgate.orchestration;

import br.com.integralltech.archgate.orchestration.config.OrchestrationProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = {
    "archgate.orchestration.api-token=homologation-test-token",
    "archgate.orchestration.webhook-secret=homologation-webhook-secret",
    "archgate.orchestration.archguard.base-url=https://archguard.test",
    "archgate.orchestration.archguard.token=test-token",
    "archgate.orchestration.warpgate.base-url=https://warpgate.test",
    "archgate.orchestration.warpgate.token=test-token",
    "archgate.orchestration.guacamole.base-url=https://guacamole.test",
    "archgate.orchestration.guacamole.token=test-token",
    "archgate.orchestration.openbao.base-url=https://openbao.test",
    "archgate.orchestration.openbao.token=test-token"
})
@ActiveProfiles("production")
class ProductionProfileConfigTest {

  @Autowired
  private OrchestrationProperties properties;

  @Test
  void productionProfileDisablesSimulationAndEnablesReplayProtection() {
    assertThat(properties.isLive()).isTrue();
    assertThat(properties.dryRun()).isFalse();
    assertThat(properties.webhookReplayProtection()).isTrue();
    assertThat(properties.archguard().enabled()).isTrue();
    assertThat(properties.warpgate().enabled()).isTrue();
    assertThat(properties.guacamole().enabled()).isTrue();
    assertThat(properties.openbao().enabled()).isTrue();
  }
}

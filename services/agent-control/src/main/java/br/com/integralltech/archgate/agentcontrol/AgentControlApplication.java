package br.com.integralltech.archgate.agentcontrol;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AgentControlApplication {

  public static void main(String[] args) {
    SpringApplication.run(AgentControlApplication.class, args);
  }
}

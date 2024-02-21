package org.worldwidereh.rehplacerbot;


import discord4j.core.DiscordClient;
import discord4j.core.GatewayDiscordClient;
import discord4j.core.event.domain.lifecycle.ReadyEvent;
import discord4j.core.object.entity.User;
import org.springframework.boot.SpringApplication;
import reactor.core.publisher.Mono;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class RehPlacerBot {
    public static void main(String[] args) {
        SpringApplication.run(RehPlacerBot.class, args);
    }
}

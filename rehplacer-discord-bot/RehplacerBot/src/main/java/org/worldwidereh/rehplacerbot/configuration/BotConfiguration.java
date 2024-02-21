package org.worldwidereh.rehplacerbot.configuration;

import discord4j.core.DiscordClientBuilder;
import discord4j.core.GatewayDiscordClient;
import discord4j.core.event.domain.Event;
import discord4j.core.object.presence.ClientActivity;
import discord4j.core.object.presence.ClientPresence;
import discord4j.rest.RestClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;


@Configuration
public class BotConfiguration {

    @Value("${discord.bot.token}")
    private String token;

    @Bean
    public <T extends Event> GatewayDiscordClient gatewayDiscordClient() {
        GatewayDiscordClient client = null;
        try {
            client = DiscordClientBuilder.create(token)
                    .build()
                    .gateway()
                    .setInitialPresence(ignore -> ClientPresence.online(ClientActivity.listening("/commands")))
                    .login()
                    .block();

        } catch (IllegalArgumentException error) {
            System.out.println(
                            """
                            
                            **********************************
                            ERROR: You tried with an invalid token. Make sure bot can get the Discord token. :)
                            **********************************
                            
                            """);
            System.exit(1);
        }
        return client;
    }

    @Bean
    public RestClient discordRestClient(GatewayDiscordClient client) {
        return client.getRestClient();
    }
}

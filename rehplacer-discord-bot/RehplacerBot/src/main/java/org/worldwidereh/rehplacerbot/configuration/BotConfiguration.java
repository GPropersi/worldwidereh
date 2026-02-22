package org.worldwidereh.rehplacerbot.configuration;

import discord4j.common.ReactorResources;
import discord4j.core.DiscordClientBuilder;
import discord4j.core.GatewayDiscordClient;
import discord4j.core.object.presence.ClientActivity;
import discord4j.core.object.presence.ClientPresence;
import discord4j.rest.RestClient;
import io.netty.channel.ChannelOption;

import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import reactor.core.scheduler.Schedulers;
import reactor.netty.http.client.HttpClient;
import reactor.netty.resources.ConnectionProvider;


@Configuration
public class BotConfiguration {

    @Value("${discord.bot.token}")
    private String token;

    @Bean
    public GatewayDiscordClient gatewayDiscordClient() {
        ConnectionProvider provider = ConnectionProvider.builder("discord")
            .maxConnections(50)
            .maxIdleTime(Duration.ofSeconds(30))
            .maxLifeTime(Duration.ofMinutes(5))
            .evictInBackground(Duration.ofSeconds(30))
            .build();

        HttpClient httpClient = HttpClient.create(provider)
            .keepAlive(true)
            .option(ChannelOption.SO_KEEPALIVE, true);

        ReactorResources resources = new ReactorResources(httpClient, Schedulers.parallel(), Schedulers.parallel());

        try {
            return DiscordClientBuilder.create(token)
                    .setReactorResources(resources)
                    .build()
                    .gateway()
                    .setInitialPresence(ignore -> ClientPresence.online(ClientActivity.listening("/commands")))
                    .login()
                    .block();

        } catch (IllegalArgumentException error) {
            throw new RuntimeException(
                            """
                            
                            **********************************
                            ERROR: You tried with an invalid token. Make sure bot can get the Discord token. :)
                            **********************************
                            
                            """, error);
        }
    }

    @Bean
    public RestClient discordRestClient(GatewayDiscordClient client) {
        return client.getRestClient();
    }
}

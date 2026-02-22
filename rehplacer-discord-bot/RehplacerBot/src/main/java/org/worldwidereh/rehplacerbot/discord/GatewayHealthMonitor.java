package org.worldwidereh.rehplacerbot.discord;

import discord4j.core.GatewayDiscordClient;
import discord4j.core.event.domain.lifecycle.ConnectEvent;
import discord4j.core.event.domain.lifecycle.DisconnectEvent;

import org.springframework.stereotype.Component;

@Component
public class GatewayHealthMonitor {

    public GatewayHealthMonitor(GatewayDiscordClient client) {
        // Listen for Disconnects
        client.on(DisconnectEvent.class)
            .subscribe(event -> {
                System.out.println("Gateway disconnected! Reason: " + event.getCause()
                    .map(Throwable::getMessage)
                    .orElse("Unknown"));
            });

        // Listen for Reconnects (Success)
        client.on(ConnectEvent.class)
            .subscribe(event -> System.out.println("Gateway connected and ready."));
    }
}

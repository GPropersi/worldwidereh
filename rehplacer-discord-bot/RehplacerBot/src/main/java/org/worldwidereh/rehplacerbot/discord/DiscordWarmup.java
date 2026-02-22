package org.worldwidereh.rehplacerbot.discord;

import discord4j.rest.RestClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.util.retry.Retry;

import java.time.Duration;

@Component
public class DiscordWarmup {

    private static final Logger log = LoggerFactory.getLogger(DiscordWarmup.class);
    private final RestClient client;

    public DiscordWarmup(RestClient client) {
        this.client = client;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void startWarmupLoop() {
        Flux.interval(Duration.ZERO, Duration.ofMinutes(5))
                .flatMap(tick -> client.getApplicationInfo()
                        .doOnSuccess(info -> log.debug("Discord REST cache warmed for: {}", info.name()))
                        .onErrorResume(e -> {
                            log.warn("Warmup ping failed: {}", e.getMessage());
                            return Mono.empty();
                        }))
                // Ensure the loop doesn't die if one request fails
                .retryWhen(Retry.fixedDelay(Long.MAX_VALUE, Duration.ofSeconds(10)))
                .subscribe();
    }
}

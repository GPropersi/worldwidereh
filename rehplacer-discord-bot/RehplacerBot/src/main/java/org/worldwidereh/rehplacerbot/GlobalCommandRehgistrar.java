package org.worldwidereh.rehplacerbot;

import discord4j.common.JacksonResources;
import discord4j.discordjson.json.ApplicationCommandRequest;
import discord4j.rest.RestClient;
import discord4j.rest.service.ApplicationService;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
public final class GlobalCommandRehgistrar implements ApplicationRunner {
    private final RestClient client;

    public GlobalCommandRehgistrar(RestClient client) {
        this.client = client;
    }

    @Override
    public void run(ApplicationArguments args) throws IOException {
        // Create an ObjectMapper that supports Discord4J classes
        final JacksonResources d4jMapper = JacksonResources.create();

        PathMatchingResourcePatternResolver matcher = new PathMatchingResourcePatternResolver();

        List<ApplicationCommandRequest> commands = new ArrayList<>();
        for (Resource resource : matcher.getResources("commands/*.json")) {
            // Read in all the JSON formatted commands for the bot
            ApplicationCommandRequest request = d4jMapper.getObjectMapper()
                    .readValue(resource.getInputStream(), ApplicationCommandRequest.class);

            commands.add(request);
        }

        final ApplicationService applicationService = client.getApplicationService();
        final Optional<Long> applicationID = client.getApplicationId().blockOptional();
        applicationID.ifPresent(appID -> applicationService.bulkOverwriteGlobalApplicationCommand(appID, commands)
                .doOnNext(ignore -> System.out.println("Registered global commands"))
                .doOnError(Throwable::printStackTrace)
                .subscribe());
    }


}

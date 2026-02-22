package org.worldwidereh.rehplacerbot.commands;

import discord4j.core.event.domain.interaction.ChatInputInteractionEvent;
import discord4j.core.object.command.ApplicationCommandInteractionOption;
import discord4j.core.object.command.ApplicationCommandInteractionOptionValue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.worldwidereh.rehplacerbot.api.rehplacer.RehToDiscordDto;
import org.worldwidereh.rehplacerbot.api.rehplacer.RehplacerApi;
import reactor.core.publisher.Mono;

@Component
public final class RehplaceCommand implements SlashCommand {

    private final RehplacerApi rehplacerApi;

    private static final Logger log = LoggerFactory.getLogger(RehplaceCommand.class);

    public RehplaceCommand(RehplacerApi rehplacerApi) {
        this.rehplacerApi = rehplacerApi;
    }

    @Override
    public String getName() {
        return "rehplace";
    }

    @Override
    public Mono<Void> handle(ChatInputInteractionEvent event) {
        log.info("Handling a rehplace...");
        String phrase = event.getOption("phrehse")
                .flatMap(ApplicationCommandInteractionOption::getValue)
                .map(ApplicationCommandInteractionOptionValue::asString)
                .get(); // Since required, can ignore this warning

        RehToDiscordDto rehToDiscordDto = rehplacerApi.rehquestRehplacement(phrase);

        if (rehToDiscordDto.isValid()) {
            log.debug("Rehplace successful: " + rehToDiscordDto.rehsponse());
            return event.reply()
                    .withEphemeral(false)
                    .withContent(buildResponse(phrase, rehToDiscordDto.rehsponse()));
        }

        log.debug("Rehplace failed...!");
        return event.reply()
                .withEphemeral(false)
                .withContent(String.format("`ERROR:` %s", rehToDiscordDto.rehsponse()));
    }

    private String buildResponse(String original, String modified) {
        return String.format("`Original:` %s\n\n`Modified:` %s", original, modified);
    }
}

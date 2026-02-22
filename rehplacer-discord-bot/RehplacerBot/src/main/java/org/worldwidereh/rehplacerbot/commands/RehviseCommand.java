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
public final class RehviseCommand implements SlashCommand {

    private final RehplacerApi rehplacerApi;

    private static final Logger log = LoggerFactory.getLogger(RehviseCommand.class);

    public RehviseCommand(RehplacerApi rehplacerApi) {
        this.rehplacerApi = rehplacerApi;
    }

    @Override
    public String getName() {
        return "rehvise";
    }

    @Override
    public Mono<Void> handle(ChatInputInteractionEvent event) {
        log.info("Handling a rehvise...");
        String phrase = event.getOption("phrehse")
                .flatMap(ApplicationCommandInteractionOption::getValue)
                .map(ApplicationCommandInteractionOptionValue::asString)
                .get(); // Since required, can ignore this warning

        RehToDiscordDto rehToDiscordDto = rehplacerApi.rehquestRehplacement(phrase);

        if (rehToDiscordDto.isValid()) {
            log.debug("Rehvise successful: " + rehToDiscordDto.rehsponse());
            return event.reply()
                    .withEphemeral(false)
                    .withContent(rehToDiscordDto.rehsponse());
        }

        log.debug("Rehvise failure!");
        return event.reply()
                .withEphemeral(false)
                .withContent(String.format("`ERROR:` %s", rehToDiscordDto.rehsponse()));
    }
}

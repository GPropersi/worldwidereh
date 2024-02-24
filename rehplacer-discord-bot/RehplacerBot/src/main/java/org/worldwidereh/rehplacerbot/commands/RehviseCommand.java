package org.worldwidereh.rehplacerbot.commands;

import discord4j.core.event.domain.interaction.ChatInputInteractionEvent;
import discord4j.core.object.command.ApplicationCommandInteractionOption;
import discord4j.core.object.command.ApplicationCommandInteractionOptionValue;
import org.springframework.stereotype.Component;
import org.worldwidereh.rehplacerbot.api.rehplacer.RehToDiscordDto;
import org.worldwidereh.rehplacerbot.api.rehplacer.RehplacerApi;
import reactor.core.publisher.Mono;

@Component
public final class RehviseCommand implements SlashCommand {

    private final RehplacerApi rehplacerApi;

    public RehviseCommand(RehplacerApi rehplacerApi) {
        this.rehplacerApi = rehplacerApi;
    }

    @Override
    public String getName() {
        return "rehvise";
    }

    @Override
    public Mono<Void> handle(ChatInputInteractionEvent event) {
        String phrase = event.getOption("phrehse")
                .flatMap(ApplicationCommandInteractionOption::getValue)
                .map(ApplicationCommandInteractionOptionValue::asString)
                .get(); // Since required, can ignore this warning

        RehToDiscordDto rehToDiscordDto = rehplacerApi.rehquestRehplacement(phrase);

        if (rehToDiscordDto.isValid()) {
            return event.reply()
                    .withEphemeral(false)
                    .withContent(rehToDiscordDto.rehsponse());
        }

        return event.reply()
                .withEphemeral(false)
                .withContent(String.format("`ERROR:` %s", rehToDiscordDto.rehsponse()));
    }
}

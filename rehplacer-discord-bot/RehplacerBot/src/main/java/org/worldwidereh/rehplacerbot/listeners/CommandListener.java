package org.worldwidereh.rehplacerbot.listeners;

import discord4j.core.GatewayDiscordClient;
import discord4j.core.event.domain.interaction.ChatInputInteractionEvent;
import org.springframework.stereotype.Component;
import org.worldwidereh.rehplacerbot.commands.SlashCommand;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.Collection;
import java.util.List;

@Component
public final class CommandListener {

    private final Collection<SlashCommand> commands;

    public CommandListener(List<SlashCommand> slashCommands, GatewayDiscordClient client) {
        commands = slashCommands;

        client.on(ChatInputInteractionEvent.class, this::handle).subscribe();
    }

    public Mono<Void> handle(ChatInputInteractionEvent event) {
        // Convert list to Flux to iterate through
        return Flux.fromIterable(commands)
                // Filter out commands that don't match prescribed event name
                .filter(command -> command.getName().equals(event.getCommandName()))
                // Get first and only item in flux that matches filter
                .next()
                // Handle command event in command class
                .flatMap(command -> command.handle(event));
    }
}

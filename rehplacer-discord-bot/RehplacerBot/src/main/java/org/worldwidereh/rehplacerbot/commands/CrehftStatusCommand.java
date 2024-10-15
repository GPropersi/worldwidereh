package org.worldwidereh.rehplacerbot.commands;

import discord4j.core.event.domain.interaction.ChatInputInteractionEvent;
import org.springframework.stereotype.Component;
import org.worldwidereh.rehplacerbot.api.crehft.CrehftStatusApi;
import org.worldwidereh.rehplacerbot.api.crehft.CrehftStatusFromApiDto;
import org.worldwidereh.rehplacerbot.api.crehft.PlayerDto;
import org.worldwidereh.rehplacerbot.api.crehft.PlayersFromCrehftStatusDto;
import reactor.core.publisher.Mono;

import java.util.stream.Collectors;

@Component
public final class CrehftStatusCommand implements SlashCommand {

    private final CrehftStatusApi crehftStatusApi;

    public CrehftStatusCommand(CrehftStatusApi crehftStatusApi) {
        this.crehftStatusApi = crehftStatusApi;
    }

    @Override
    public String getName() {
        return "crehft-status";
    }

    @Override
    public Mono<Void> handle(ChatInputInteractionEvent event) {
        CrehftStatusFromApiDto crehftStatusFromApiDto = crehftStatusApi.getCrehftStatus();

        if (crehftStatusFromApiDto != null) {
            return event.reply()
                    .withEphemeral(false)
                    .withContent(buildResponse(crehftStatusFromApiDto.online(), crehftStatusFromApiDto.players(), crehftStatusFromApiDto.apiOnline()));
        }

        return event.reply()
                .withEphemeral(false)
                .withContent("`ERROR:` UNABLE TO CHECK SERVER STATUS");
    }

    private String buildResponse(boolean serverOnline, PlayersFromCrehftStatusDto playersFromCrehftStatusDto, boolean validApiResponse) {
        if (!validApiResponse) {
            return "`ERROR:` INVALID API RESPONSE";
        }
        if (!serverOnline) {
            String offlineMessage = "No... The server is offline.\n------------------------------------------------------------\n";
            return String.format("## Can you crehft?\n```asciidoc\n%s\n```", offlineMessage);
        }
        return String.format("## Can you crehft? ***Yes!***\n\n------------------------------------------------------------\n## Server: Online!\n\n------------------------------------------------------------\n## Players: %s", buildPlayerResponse(playersFromCrehftStatusDto));
    }

    private String buildPlayerResponse(PlayersFromCrehftStatusDto playersFromCrehftStatusDto) {
        if (playersFromCrehftStatusDto.online() == 0) return "\n`No Players Online :(`";

        return String.format("\n```asciidoc\n%s\n```", playersFromCrehftStatusDto.list().stream()
                .map(PlayerDto::name)
                .collect(Collectors.joining("", "- ", "\n")));
    }
}

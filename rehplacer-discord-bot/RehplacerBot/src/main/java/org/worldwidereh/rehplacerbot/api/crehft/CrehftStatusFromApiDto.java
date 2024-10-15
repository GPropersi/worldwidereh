package org.worldwidereh.rehplacerbot.api.crehft;

public record CrehftStatusFromApiDto(
        Boolean online,
        PlayersFromCrehftStatusDto players,
        Boolean apiOnline
) { public CrehftStatusFromApiDto {
    if (apiOnline == null) apiOnline = true;
}}
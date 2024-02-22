# Rehplacer Discord Bot <img src='https://i.imgur.com/1eorJ6H.jpeg' width='25'>
Welcome to the home of the Rehplacer Discord Bot!

## What does this do?

Simple - this bot takes a command `/rehplace` and reads your text in the `phrehse` argument.

The text is then modified where every `r` followed by a vowel, is replaced with `REH`.

## How does it do it?

It uses the [Discord4j](https://docs.discord4j.com) library to build the Discord bot, along with [Spring](https://spring.io/).

The bot makes a POST request with a body containing the original text to a Cloudflare Worker at: https://rehplacer.propersi.me

With valid credentials, this Worker responds with modified text, where every `r` followed by a vowel is replaced with `REH`.

---

## Environment Variables

The `application.properties` file, typically associated with a Spring project, holds the key environment variables that are
injected throughout the code. Hence, it is kept out of source control. As these credentials are necessary to both validating
your ownership of the bot, and performing a valid request to the Worker, we won't dive into these variables any further. :)


---

## Rehsponsibly Rehnning The Bot

Assuming all valid environment variables are set, to run locally, one would need enter the `RehplacerBot` directory, which contains all necessary `gradle` files to run using gradle.

Once in the directory:

> To run, type in :`./gradlew bootRun`
>
> To make a JAR file: `./gradlew bootJar`
>
> This wil output a JAR file in the `builds/libs` directory, which can also be used to run the bot.

Have fun :).

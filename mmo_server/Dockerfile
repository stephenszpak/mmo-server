FROM elixir:1.17-alpine AS build
RUN apk add --no-cache build-base git npm
WORKDIR /app
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod
COPY . .
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix assets.deploy
RUN mix release

FROM alpine:3.18 AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs
WORKDIR /app
COPY --from=build /app/_build/prod/rel/mmo_server .
ENV HOME=/app
CMD ["bin/mmo_server", "start"]

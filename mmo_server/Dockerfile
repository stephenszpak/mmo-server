FROM elixir:1.18-alpine AS build
WORKDIR /app
ENV MIX_ENV=prod

RUN apk add --no-cache build-base git
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
COPY . .
RUN mix compile

FROM elixir:1.18-alpine
WORKDIR /app
COPY --from=build /app .
CMD ["elixir", "--sname", "mmo", "-S", "mix", "phx.server"]

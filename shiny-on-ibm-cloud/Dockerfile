FROM rocker/shiny:latest
WORKDIR /srv/shiny-server/
RUN ["install2.r", "abind", "tibble"]
COPY . .

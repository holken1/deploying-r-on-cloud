FROM trestletech/plumber
WORKDIR /R/
COPY . .
EXPOSE 8000
RUN ["install2.r", "ggplot2", "readr"]
RUN ["R", "-f", "/R/create-model.R"]
CMD ["/R/score-lm.R"]

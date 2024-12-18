# docker build -t sezam.web .
FROM mcr.microsoft.com/dotnet/aspnet:9.0
COPY bin/net9.0/publish/ /app
WORKDIR /app
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 80

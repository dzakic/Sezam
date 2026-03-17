FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base-runtime
WORKDIR /app

COPY bin/net10.0/publish/[^Sezam]*.dll ./
COPY bin/net10.0/publish/[^Sezam]* ./
COPY bin/net10.0/publish/Sezam* ./


ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 8080
EXPOSE 2023

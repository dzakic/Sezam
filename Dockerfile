# docker build -t sezam.web .
FROM mcr.microsoft.com/dotnet/aspnet
COPY bin/net8.0/publish/ /app
WORKDIR /app
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 80

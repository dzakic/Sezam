FROM mcr.microsoft.com/dotnet/aspnet
COPY bin/net5.0/publish/ /app
WORKDIR /app
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 80

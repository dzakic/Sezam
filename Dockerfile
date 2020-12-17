FROM mcr.microsoft.com/dotnet/aspnet
COPY publish/ /app
WORKDIR /app
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 80



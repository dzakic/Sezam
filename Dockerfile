FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app
COPY . ./
RUN dotnet restore
RUN dotnet publish -c Release

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build-env /app/bin/net9.0/publish .
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 8080
EXPOSE 23
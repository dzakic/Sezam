# Stage 1: Restore dependencies
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS base-env
WORKDIR /app
COPY Sezam.sln ./
# Copy only project files to keep the restore layer stable
COPY Console/*.csproj ./Console/
COPY Commands/*.csproj ./Commands/
COPY Web/*.csproj ./Web/
COPY Telnet/*.csproj ./Telnet/
COPY Legacy/Import/*.csproj ./Legacy/Import/
COPY Tests/Sezam.Tests/*.csproj ./Tests/Sezam.Tests/
COPY Data/*.csproj ./Data/
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet restore

# 2. Publish dependencies (will be fast because restore is done)
FROM base-env AS build-env
COPY . ./
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet publish -c Release -o /app/publish \
    -r linux-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:DebugType=None \
    -p:DebugSymbols=false \
    Web/Sezam.Web.csproj
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet publish -c Release -o /app/publish \
    -r linux-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:DebugType=None \
    -p:DebugSymbols=false \
    Telnet/Sezam.Telnet.csproj

# 4. Final stage: runtime image(s) for each COPY
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base-runtime
USER root
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

FROM base-runtime AS runtime-env
WORKDIR /app

# Layer A: The heavy stuff (NuGet + Static Assets)
COPY --from=build-env /app/publish/appsettings.json ./
COPY --from=build-env /app/publish/wwwroot/ ./wwwroot/

# Layer B: The frequent code changes
COPY --from=build-env /app/publish/Sezam.* ./
ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 8080
EXPOSE 2023
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
    dotnet restore && \
    dotnet publish Telnet/Sezam.Telnet.csproj \
        -c Release \
        -r linux-x64 \
        -o /app/dep \
        -p:DebugType=None \
        -p:DebugSymbols=false \
        -p:Versions=0.0.0 \
        -p:AssemblyVersion=0.0.0 \
        -p:GenerateAppBundle=false \
        -p:OutputType=Library && \
    dotnet publish Web/Sezam.Web.csproj \
        -c Release \
        -r linux-x64 \
        -o /app/dep \
        -p:DebugType=None \
        -p:DebugSymbols=false \
        -p:Versions=0.0.0 \
        -p:AssemblyVersion=0.0.0 \
        -p:GenerateAppBundle=false \
        -p:OutputType=Library && \
    rm -f /app/dep/Sezam*

# 2. Publish dependencies (will be fast because restore is done)
FROM base-env AS build-env
ARG APP_VERSION=1.0.0 # Default
COPY . ./
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet publish -c Release . \
    -r linux-x64 \
    -p:DebugType=None \
    -p:DebugSymbols=false \
    -p:Versions=${APP_VERSION} \
    -p:AssemblyVersion=${APP_VERSION}

RUN mv bin/net10.0/linux-x64/publish /app/publish && \
    mkdir /app/sez && \
    mv /app/publish/Sezam* /app/sez && \
    mv /app/publish/*.dll /app/dep

# 4. Final stage: runtime image(s) for each COPY
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime-env
WORKDIR /app

# Layer A: The heavy stuff (NuGet + Static Assets)
COPY --from=base-env /app/dep/* ./

# Layer B: The frequent code changes
COPY --from=build-env /app/publish/wwwroot/ ./wwwroot/
COPY --from=build-env /app/publish/sr/ ./sr/
COPY --from=build-env /app/sez/* ./

# ENTRYPOINT [ "/app/Sezam.Web" ]
EXPOSE 8080
EXPOSE 2023

# ─────────────────────────────────────────────────────────────────────────────
#  PacEHR.API (ASP.NET Core 8) — local container image
#
#  This file lives OUTSIDE the pacEHR_API repo on purpose; the repo is used
#  only as a read-only build context. Build it through scripts/build.sh, which
#  passes the right context and ignore file:
#      podman build -f containerfiles/api.Containerfile \
#                   --ignorefile containerfiles/api.ignore  <path-to-pacEHR_API>
# ─────────────────────────────────────────────────────────────────────────────

# ── build stage ─────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Only the projects PacEHR.API actually references. The SSDT database project
# (PacEHR.Database) and the test projects are deliberately left out — they are
# not restorable/needed here. Copying .csproj files first keeps the restore
# layer cached when only source files change.
COPY PacEHR.API/PacEHR.API.csproj                                   PacEHR.API/
COPY pacEHR.DomainServices/PacEHR.DomainServices.csproj             pacEHR.DomainServices/
COPY pacEHR.DomainServices.Interfaces/PacEHR.DomainServices.Interfaces.csproj pacEHR.DomainServices.Interfaces/
COPY pacEHR.PCC.Services/pacEHR.PCC.Services.csproj                 pacEHR.PCC.Services/
COPY PacEHR.Functions.Process/PacEHR.Functions.Process.csproj       PacEHR.Functions.Process/
COPY pacEHR.Data.Dtos/PacEHR.Data.Dtos.csproj                       pacEHR.Data.Dtos/
COPY PacEHR.Data/PacEHR.Data.csproj                                 PacEHR.Data/
# Legacy managed assembly referenced by HintPath from PacEHR.API.csproj.
COPY CCDA.dll ./

RUN dotnet restore PacEHR.API/PacEHR.API.csproj

COPY PacEHR.API/                        PacEHR.API/
COPY pacEHR.DomainServices/             pacEHR.DomainServices/
COPY pacEHR.DomainServices.Interfaces/  pacEHR.DomainServices.Interfaces/
COPY pacEHR.PCC.Services/               pacEHR.PCC.Services/
COPY PacEHR.Functions.Process/          PacEHR.Functions.Process/
COPY pacEHR.Data.Dtos/                  pacEHR.Data.Dtos/
COPY PacEHR.Data/                       PacEHR.Data/

RUN dotnet publish PacEHR.API/PacEHR.API.csproj -c Release -o /app/publish --no-restore

# ── runtime stage ───────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# .NET 8 auto-detects containers and honours ASPNETCORE_HTTP_PORTS; set it
# explicitly so the listening port is obvious rather than implied.
ENV ASPNETCORE_HTTP_PORTS=8080
ENV ASPNETCORE_ENVIRONMENT=Development
EXPOSE 8080

ENTRYPOINT ["dotnet", "PacEHR.API.dll"]

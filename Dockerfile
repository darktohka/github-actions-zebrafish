FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder

COPY ./code /code

RUN \
  if [ "$(uname -m)" = "x86_64" ]; then \
    PACKAGE_RUNTIME_MUSL="linux-musl-x64"; \
    PACKAGE_RUNTIME="linux-x64"; \
  else \
    PACKAGE_RUNTIME_MUSL="linux-musl-arm64"; \
    PACKAGE_RUNTIME="linux-arm64"; \
  fi && \
  apk add --no-cache --virtual .dev-deps curl && \
  cd /tmp && \
  git clone --depth=1 https://github.com/actions/runner && cd runner && \
  rm src/global.json && \
  find ./ -type f \( -name '*.csproj' -or -name '*.props' \) -exec sed -i "s/${PACKAGE_RUNTIME}/${PACKAGE_RUNTIME_MUSL}/g" {} \; && \
  sed -i 's/path = new DirectoryInfo(GetDirectory(WellKnownDirectory.Bin)).Parent.FullName;/path = "\/srv";/g' src/Runner.Common/HostContext.cs && \
  mv /code/SelfUpdater.cs src/Runner.Listener/SelfUpdater.cs && \
  mv /code/SelfUpdaterV2.cs src/Runner.Listener/SelfUpdaterV2.cs && \
  dotnet msbuild -t:Build -p:PackageRuntime="$PACKAGE_RUNTIME_MUSL" -p:BUILDCONFIG="Release" -p:RunnerVersion="$(cat src/runnerversion)" -p:SelfContained=true src/dir.proj && \
  cp -r _layout/bin/* /srv/ && \
  rm -rf /tmp/* /root/.nuget /root/.nuget /root/.dotnet /root/.local && \
  apk del .dev-deps

FROM alpine

RUN apk add --upgrade --no-cache ca-certificates-bundle libgcc libssl3 libstdc++ zlib git icu-libs nodejs curl bash jq && \
  apk add --no-cache --virtual .dev-deps go && \
  cd /tmp && \
  git clone --depth=1 https://github.com/moby/buildkit && \
  cd buildkit && \
  go build -buildvcs=false $(pwd)/cmd/buildctl && \
  mv buildctl /usr/bin/buildctl && \
  cd /tmp && \
  rm -rf /tmp/* /root/go /root/.cache /var/git && \
  apk del .dev-deps

RUN mkdir -p /srv/externals/node20/bin && mkdir -p /srv/externals/node16/bin && \
  ln -s /usr/bin/node /srv/externals/node20/bin/node && \
  ln -s /usr/bin/node /srv/externals/node16/bin/node

COPY --from=builder /srv /srv
COPY ./scripts/* /usr/bin/

WORKDIR /work

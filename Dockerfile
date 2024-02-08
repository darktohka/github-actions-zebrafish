FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS gh-builder

ARG TARGETPLATFORM
COPY ./code /code

RUN \
  if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
  PACKAGE_RUNTIME_MUSL="linux-musl-x64"; \
  PACKAGE_RUNTIME="linux-x64"; \
  elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
  PACKAGE_RUNTIME_MUSL="linux-musl-arm64"; \
  PACKAGE_RUNTIME="linux-arm64"; \
  else \
  PACKAGE_RUNTIME_MUSL="linux-musl-arm"; \
  PACKAGE_RUNTIME="linux-arm"; \
  fi && \
  apk add --no-cache --virtual .dev-deps curl && \
  cd /tmp && \
  git clone --depth=1 https://github.com/actions/runner && cd runner && \
  rm src/global.json && \
  find ./ -type f \( -name '*.csproj' -or -name '*.props' \) -exec sed -i "s/${PACKAGE_RUNTIME}/${PACKAGE_RUNTIME_MUSL}/g" {} \; && \
  sed -i 's/path = new DirectoryInfo(GetDirectory(WellKnownDirectory.Bin)).Parent.FullName;/path = "\/srv";/g' src/Runner.Common/HostContext.cs && \
  sed -i 's/5.2.1/7.2.0/g' src/Sdk/Sdk.csproj && \
  mv /code/SelfUpdater.cs src/Runner.Listener/SelfUpdater.cs && \
  mv /code/SelfUpdaterV2.cs src/Runner.Listener/SelfUpdaterV2.cs && \
  dotnet msbuild -t:Build -p:PackageRuntime="$PACKAGE_RUNTIME_MUSL" -p:BUILDCONFIG="Release" -p:RunnerVersion="$(cat src/runnerversion)" -p:SelfContained=true src/dir.proj && \
  cp -r _layout/bin/* /srv/ && \
  rm -rf /tmp/* /root/.nuget /root/.nuget /root/.dotnet /root/.local && \
  apk del .dev-deps && \
  mkdir -p /srv/externals/node20/bin && mkdir -p /srv/externals/node16/bin && \
  ln -s /usr/bin/node /srv/externals/node20/bin/node && \
  ln -s /usr/bin/node /srv/externals/node16/bin/node

FROM --platform=$BUILDPLATFORM golang:alpine AS buildkit-builder

ARG TARGETPLATFORM
ENV CGO_ENABLED=1

COPY --from=xx / /

RUN apk add --no-cache --virtual .dev-deps curl llvm && \
  cd /tmp && \
  curl -sL https://api.github.com/repos/moby/buildkit/tarball/master | tar -xz && \
  cd moby-buildkit* && \
  xx-go build -buildvcs=false $(pwd)/cmd/buildctl && \
  llvm-strip buildctl && \
  mv buildctl /srv/buildctl && \
  curl -sL https://api.github.com/repos/containers/podman/tarball/main | tar -xz && \
  cd containers-podman* && \
  xx-go build $(pwd)/cmd/podman && \
  llvm-strip podman && \
  mv podman /srv/podman && \
  rm -rf /tmp/* /root/go /root/.cache && \
  apk del .dev-deps

FROM alpine:edge

RUN \
  apk add --upgrade --no-cache ca-certificates-bundle libgcc libssl3 libstdc++ zlib git icu-libs nodejs bash jq openssh-client-default doas && \
  ln -s /usr/bin/doas /usr/bin/sudo && \
  echo "permit nopass root" > /etc/doas.conf && \
  rm -rf /tmp/* /var/git

COPY --from=gh-builder /srv /srv
COPY --from=buildkit-builder /srv/buildctl /usr/bin/buildctl
COPY --from=buildkit-builder /srv/nerdctl /usr/bin/nerdctl
COPY ./scripts/* /usr/bin/

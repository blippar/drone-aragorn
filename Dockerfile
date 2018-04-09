## Repository: blippar/drone-aragorn
## Tags:       ["latest", "1.3.1"]
FROM blippar/aragorn:1.3.1 as aragorn
FROM alpine:latest AS drone

RUN apk add --no-cache ca-certificates jq coreutils

COPY --from=aragorn /usr/bin/aragorn /usr/bin/aragorn
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

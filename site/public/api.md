# FanBar Product Facts API

> A public, read-only API exposing canonical FanBar product, compatibility, installation, and safety facts. No key or account is required.

- Documentation: https://getfanbar.com/api
- API catalog: https://getfanbar.com/.well-known/api-catalog
- OpenAPI 3.1 description: https://getfanbar.com/openapi.json
- Last updated: 2026-10-20
- API version: 1.1.0

## Endpoints

### Product facts

`GET https://getfanbar.com/api/product.json`

Returns canonical product, pricing, compatibility, installation, feature, language, and safety facts as JSON.

It also includes:

- `latestRelease`: version, publish time, release notes page, and GitHub release URL of the current FanBar release.
- `downloads`: the latest notarized DMGs keyed by architecture (`universal`, `arm64`, `x86_64`), each with file name, URL, and size in bytes.
- `localizedPages`: the product page for each language tag (`en`, `zh-Hans`, `zh-Hant`, `ja`, `ru`, `fr`).

Release and download fields are generated at build time from the same release snapshot as the website's download buttons.

### Publication status

`GET https://getfanbar.com/api/health.json`

Returns a small JSON status document confirming that the static API is available.

## Discovery

`GET https://getfanbar.com/.well-known/api-catalog`

Returns RFC 9727 Linkset JSON with `service-desc`, `service-doc`, and `status` relations.

## Usage

```sh
curl https://getfanbar.com/api/product.json
curl https://getfanbar.com/api/health.json
curl https://getfanbar.com/.well-known/api-catalog
```

All endpoints are read-only, public, and served over HTTPS. They do not expose device-control operations or personal data.

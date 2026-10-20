# FanBar Product Facts API

> A public, read-only API exposing canonical FanBar product, compatibility, installation, and safety facts. No key or account is required.

- Documentation: https://getfanbar.com/api
- API catalog: https://getfanbar.com/.well-known/api-catalog
- OpenAPI 3.1 description: https://getfanbar.com/openapi.json
- Last updated: 2026-10-12

## Endpoints

### Product facts

`GET https://getfanbar.com/api/product.json`

Returns canonical product, pricing, compatibility, installation, feature, language, and safety facts as JSON.

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

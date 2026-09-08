# Ghosium web services deployment note

Ghosium Browser 0.1.6 does not ship or operate a first-party web search service. Browser and New Tab searches use Google Search as an external service.

The repository keeps only the Ghosium-controlled shared-hosting services needed for product distribution:

- Store source: `store-web/`
- Update source: `updates-web/`
- Store deployment guide: `docs/SHARED-HOSTING-STORE.md`

Retired search integration, server code and deployment assets are intentionally absent.

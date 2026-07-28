# maintenance

Manual operational checklist. Nothing here gates a release, but each item goes stale if ignored for long — walk through this list from time to time.

## re-probe fee-market hints

Every catalog network carries a `feeMarketHint` with the date it was last checked (`checkedAt`). Hints never expire in the app, so they are only as good as the last probe.

```bash
cd Workers/alchemy-jwt && npm run probe:fee-markets -- --expected-kid KID --output /tmp/fee-market-candidate.json
```

`--output` requires Alchemy authorization for this catalog, so `--expected-kid` must be provided and `ALCHEMY_JWT_REQUEST_PROOF_KEY` must be available from the environment or login Keychain; the output path must not already exist. Diff the candidate against `Shared/Ethereum/NetworkCatalog.json` and apply it explicitly after reviewing the complete change. The probe never touches the source catalog. Details: `Workers/alchemy-jwt/README.md`, "Fee-market catalog probe".

## keep the network catalog and ownership set in lockstep

When adding or removing chains, update `Shared/Ethereum/NetworkCatalog.json` and `BundledNetworkOwnership.chainIds` (`Shared/Ethereum/NetworkCatalog.swift`) together. A mismatch trips the ownership kill-switch and disables the entire bundled catalog at runtime.

## before a release

- Bump the version: `Scripts/asc/bump.sh` (commit as `bump version to X.Y.Z (build)`).
- Validate localizations: `Scripts/asc/validate_localizations.sh`.

## alchemy jwt worker

- Release/verify loop: local suite → upload → rollout → verify, per `Workers/alchemy-jwt/README.md` ("First HMAC production rollout" and "Future HMAC-compatible Worker updates").
- After a signing-key rotation, respect the retirement window before removing the old public key, and mind the request-proof-key fingerprint caveat (`Scripts/alchemy_jwt_request_proof_key.sha256`). Details in the Worker README.

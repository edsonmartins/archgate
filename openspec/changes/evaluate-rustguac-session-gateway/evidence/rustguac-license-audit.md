# RustGuac dependency-license audit

Baseline: RustGuac `v1.9.7` / `a897fcc63b672907f01c74515b92ff766530f318`.

## Result

- Locked transitive packages: **474**.
- Packages without declared license/license file: **0**.
- AGPL, GPL-only, BUSL, SSPL or unknown licenses: **0**.
- Two `r-efi` versions declare `MIT OR Apache-2.0 OR LGPL-2.1-or-later`;
  ArchGate selects the permissive alternative and does not rely on LGPL.
- `ryu` declares `Apache-2.0 OR BSL-1.0`; this is the permissive **Boost
  Software License**, not Business Source License.
- Unicode-3.0, BSD, ISC, Zlib, CDLA-Permissive-2.0 and Unlicense/MIT
  alternatives require preservation in the automated attribution output.

The license gate passes provisionally. The dependency count is itself an
architectural risk and weighs against embedding the complete binary when a
smaller extraction is possible.

## Reproduction

`Cargo.lock` is the canonical locked component inventory. Metadata was
resolved with:

```bash
cargo metadata --locked --format-version 1
cargo metadata --locked --offline --format-version 1 \
  | jq -r '.packages[] | [.name,.version,.license,.license_file] | @tsv'
```

## Draft ArchGate NOTICE entry

```text
This product contains or derives portions of RustGuac v1.9.7
(commit a897fcc63b672907f01c74515b92ff766530f318),
licensed under the Apache License, Version 2.0.
Modifications and integration code are maintained by IntegrAllTech.
```

The final NOTICE must be generated from the actual selected dependency graph,
not from the full upstream feature set, and must accompany any copied source.


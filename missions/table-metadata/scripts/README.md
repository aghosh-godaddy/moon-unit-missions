# table-metadata — helper scripts

This mission intentionally relies primarily on **code analysis inside the Moon
Units container** (PySpark + DAG as truth). If we later add helper scripts
(e.g., config bootstrapping, GitHub URL parsing, or lake table lookups), they
will live in this directory.

For now, prefer the `table-metadata-config` skill + `docs/creating-a-config.md`.


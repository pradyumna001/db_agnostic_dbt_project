# ADR 0001: Own Data Vault macros instead of automate_dv

**Status:** accepted

automate_dv does not support Oracle (or SQL Server fully on current dbt). We need identical behaviour on five
adapters, so hubs, links, satellites, effectivity satellites and PITs are implemented in `macros/datavault/`
using only portable SQL (`row_number()` instead of `QUALIFY`, anti-joins instead of dialect `MERGE`).
Platform differences are pushed down into small dispatched helpers (types, hashing, dates).

Consequence: we own the maintenance, but the macros are small and covered by the vault tests and
the incremental-vs-full-refresh comparison.

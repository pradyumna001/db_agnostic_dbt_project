# ADR 0003: Performance tuning as model metadata

**Status:** accepted

Model SQL is shared. Physical design (indexes, clustering, stats, OPTIMIZE) is declared in `meta.perf`
and translated per adapter in a post-hook. Adding a platform means adding one dispatch implementation,
not touching models.

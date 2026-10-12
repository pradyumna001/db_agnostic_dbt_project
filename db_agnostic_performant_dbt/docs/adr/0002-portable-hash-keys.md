# ADR 0002: Portable SHA-256 hash keys

**Status:** accepted

Keys must be equal across platforms so data can be reconciled and migrated. Each business key is cast to a
string, `UPPER(TRIM())`ed, nulls/empties become `^^`, parts are joined with `||`, hashed with SHA-256 over UTF-8
and rendered as uppercase hex (`char(64)`). `tests/golden/assert_hash_key_is_portable.sql` compares against
values computed in Python; it runs on every adapter in CI.

{#- Hash keys must be byte-identical on every platform (expected values computed in Python: sha256 of UTF-8). -#}
select
    g.actual,
    g.expected
from (
    select
        {{ hash_key(["'1001'"]) }} as actual,
        'FE675FE7AAEE830B6FED09B64E034F84DCBDAEB429D9CCCD4EBB90E15AF8DD71' as expected
    {{ from_dual() }}
    union all
    select
        {{ hash_key(["'  abc  '"]) }} as actual,
        'B5D4045C3F466FA91FE2CC6ABE79232A1A57CDF104F7A26E716E0A1E2789DF78' as expected
    {{ from_dual() }}
    union all
    select
        {{ hash_key(["null"]) }} as actual,
        'DD9C8445E43D2717AD906B284AE560A4E9E16EB87F64CE27D0FDF3446E64EF44' as expected
    {{ from_dual() }}
    union all
    select
        {{ hash_key(["'ZOË'"]) }} as actual,
        'D7782B2B807E798A4575929D429ECB7501F819C6CEA8CB8932E007E44E2C3B5B' as expected
    {{ from_dual() }}
    union all
    select
        {{ hash_key(["'a'", "'b'"]) }} as actual,
        'BFFECD9532FB296C45CB9A58CFB35BF97DD1A753BCBD879978415E2C84E357FF' as expected
    {{ from_dual() }}
    union all
    select
        {{ hash_key(['null', "'x'"]) }} as actual,
        'B6948C426AA8C87A4BB71F5CCA60B1901AFE60E7AC6A69420633C3567B438B83' as expected
    {{ from_dual() }}
) g
where g.actual <> g.expected

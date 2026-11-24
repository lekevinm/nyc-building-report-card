-- One row per 2020 NTA (262), with its polygon. Keeps the non-residential
-- NTAs (parks, airports, cemeteries and others), flagged by nta_type.
-- Needs the spatial extension (profiles.yml loads it) for the geom column.
-- Written by Claude at Kevin's request (Nov 23, 2026).

with source as (
    select * from {{ source('raw', 'raw_nta') }}
),

renamed as (
    select
        nta2020                       as nta_code,      -- e.g. BK0101; the key marts join on
        ntaname                       as nta_name,
        ntaabbrev                     as nta_abbrev,
        boroname                      as borough,
        cast(borocode as integer)     as boro_code,
        cdta2020                      as cdta_code,
        cdtaname                      as cdta_name,
        cast(ntatype as integer)      as nta_type,      -- 0 = residential; other codes are non-residential
        geom
        -- Left out: OGC_FID (row number added by ST_Read), shape_area,
        -- shape_leng and countyfips (not used downstream).
    from source
)

select * from renamed

-- One row per PLUTO 26v3 tax lot (858,312). Keeps every lot; the
-- rental-scope filter is applied later, in dim_building.
-- Leaves out ownername (guardrail: no owner names).
-- Hand-built by Kevin (Nov 23, 2026); formatting aligned by Claude.

with source as (
    select * from {{ source('raw', 'raw_pluto') }}
),

renamed as (
    select
        cast(bbl as bigint)           as bbl,           -- arrives as decimal text, e.g. 4087790057.00000000
        bldgclass,
        cast(unitsres as bigint)      as unitsres,      -- no values with a decimal point (checked Nov 23, 2026)
        cast(numfloors as double)     as numfloors,     -- has fractional values, e.g. 1.5
        -- 0 means unknown, so it becomes NULL.
        if(cast(yearbuilt as bigint) = 0, null, cast(yearbuilt as bigint)) as yearbuilt,
        cast(latitude as double)      as latitude,
        cast(longitude as double)     as longitude
    from source
)

select * from renamed

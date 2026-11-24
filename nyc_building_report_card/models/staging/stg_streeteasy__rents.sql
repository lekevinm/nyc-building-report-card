-- One row per StreetEasy area per month, from the wide raw file
-- (one column per month). Keeps all 182 areas (neighborhood, borough, city)
-- and all 202 months; months with no rent stay as rows with a NULL rent.
-- Written by Claude at Kevin's request (Nov 23, 2026).

with source as (
    select * from {{ source('raw', 'raw_streeteasy') }}
),

-- Wide to long. Every column except the three ID columns is a month.
-- "include nulls" keeps blank months as rows (DuckDB drops them by default).
unpivoted as (
    select *
    from source
    unpivot include nulls (
        rent_text for month_text in (columns(* exclude (areaName, Borough, areaType)))
    )
),

renamed as (
    select
        -- Key for tests: one row per area per month.
        areaName || '|' || month_text                 as area_month_id,
        areaName                                      as area_name,
        nullif(Borough, '')                           as borough,       -- NULL for the NYC city row
        areaType                                      as area_type,     -- neighborhood, borough or city
        cast(month_text || '-01' as date)             as month,         -- first day of the month
        -- Rents arrive as text like '1600.0'; all are whole numbers (checked Nov 23, 2026).
        cast(cast(rent_text as double) as integer)    as median_asking_rent
    from unpivoted
)

select * from renamed

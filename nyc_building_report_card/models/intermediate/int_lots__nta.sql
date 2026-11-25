-- One row per PLUTO lot (858,312), with the 2020 NTA its point falls in.
-- Keeps every lot, not just rentals, so Follow-ups 1 and 4 can reuse it.
-- nta_code is NULL for lots with no lat/lng or a point outside every polygon.
-- A point on a shared boundary touches two NTAs; it keeps the lower nta_code.
-- Needs the spatial extension (profiles.yml loads it).
-- Written by Claude; design calls by Kevin (Nov 23, 2026).

with lots as (
    select
        bbl,
        -- ST_Point takes x then y: longitude first.
        st_point(longitude, latitude) as lot_point
    from {{ ref('stg_pluto__lots') }}
    where latitude is not null
      and longitude is not null
),

ntas as (
    select nta_code, geom
    from {{ ref('stg_nta__boundaries') }}
),

-- Inner join on the polygon test. DuckDB plans this as a spatial join,
-- so it doesn't compare every lot with every polygon.
matched as (
    select
        lots.bbl,
        ntas.nta_code
    from lots
    inner join ntas
        on st_intersects(ntas.geom, lots.lot_point)
    qualify row_number() over (partition by lots.bbl order by ntas.nta_code) = 1
)

-- Back to every lot, so unmatched lots stay in with a NULL nta_code.
select
    all_lots.bbl,
    matched.nta_code
from {{ ref('stg_pluto__lots') }} as all_lots
left join matched
    on all_lots.bbl = matched.bbl

-- One row per rental building (BBL), in the scope from SPEC section 3:
-- class C* (walk-up) or D* (elevator) with 3 or more residential units,
-- excluding co-ops (C6, C8, CC, D0, D4, DC) and mobile homes (CM).
-- nta_code is NULL where the lot couldn't be placed in an NTA.
-- Skeleton (CTEs and join) hand-built by Kevin; rental filter, columns and
-- tidy-up by Claude at Kevin's request (Nov 24, 2026).

with lots as (
    select
        bbl,
        bldgclass,
        unitsres,
        numfloors,
        yearbuilt,
        latitude,
        longitude
    from {{ ref('stg_pluto__lots') }}
),

lot_ntas as (
    select
        bbl,
        nta_code
    from {{ ref('int_lots__nta') }}
),

rentals as (
    select *
    from lots
    where (bldgclass like 'C%' or bldgclass like 'D%')
      and unitsres >= 3
      and bldgclass not in ('C6', 'C8', 'CC', 'D0', 'D4', 'DC', 'CM')
),

-- Left join, so a rental building stays in even if it has no row in int_lots__nta.
joined as (
    select
        rentals.bbl,
        lot_ntas.nta_code,
        rentals.bldgclass,
        rentals.bldgclass like 'D%'   as has_elevator,   -- D* classes are elevator buildings
        rentals.unitsres,
        rentals.numfloors,
        rentals.yearbuilt,
        rentals.latitude,                                -- kept for the Tableau building-point fallback
        rentals.longitude
    from rentals
    left join lot_ntas
        on rentals.bbl = lot_ntas.bbl
)

select * from joined

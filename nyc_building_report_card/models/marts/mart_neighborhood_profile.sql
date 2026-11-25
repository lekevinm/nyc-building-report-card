-- One row per 2020 NTA (all 262), with StreetEasy median asking rents and a
-- profile of the NTA's rental buildings from dim_building.
-- Rent definitions (SPEC section 3, decided by Kevin on Nov 24, 2026):
--   rent_latest: the latest month with any rent in the data, the same month
--     for every NTA. NULL if none of the NTA's StreetEasy neighborhoods has a
--     rent that month.
--   rent_12m_median: the 12 months ending at that month. A StreetEasy
--     neighborhood counts only if at least var('rent_12m_min_months') of the
--     12 months have a rent.
-- An NTA mapped to several StreetEasy neighborhoods takes the median across them.
-- Drafted by Claude; design calls by Kevin (Nov 24, 2026).

with ntas as (
    select
        nta_code,
        nta_name,
        borough,
        nta_type
    from {{ ref('stg_nta__boundaries') }}
),

-- Seed rows with a StreetEasy neighborhood. Rows with match_type none or
-- non_residential have a blank area, so they drop out here.
crosswalk as (
    select
        nta_code,
        streeteasy_area
    from {{ ref('nta_to_streeteasy') }}
    where streeteasy_area is not null
),

rents as (
    select
        area_name,
        month,
        median_asking_rent
    from {{ ref('stg_streeteasy__rents') }}
    where area_type = 'neighborhood'
),

-- Taken from the data rather than hard-coded, so a refresh moves it forward.
latest_month as (
    select max(month) as month
    from rents
    where median_asking_rent is not null
),

-- One row per StreetEasy neighborhood, over the 12 months ending at the
-- latest month (date_diff 0 is the latest month, 11 is eleven months before).
area_rents as (
    select
        rents.area_name,
        max(rents.median_asking_rent) filter (where rents.month = latest_month.month) as rent_latest,
        -- NULL unless enough of the 12 months have a rent. count() of a column
        -- skips NULLs, so it counts the months that have one.
        case
            when count(rents.median_asking_rent) >= {{ var('rent_12m_min_months') }}
                then median(rents.median_asking_rent)
        end as rent_12m_median
    from rents
    cross join latest_month
    where date_diff('month', rents.month, latest_month.month) between 0 and 11
    group by rents.area_name
),

-- One row per NTA that has a StreetEasy match. median() skips NULLs, so an
-- NTA uses whichever of its neighborhoods have a value.
nta_rents as (
    select
        crosswalk.nta_code,
        string_agg(crosswalk.streeteasy_area, ', ' order by crosswalk.streeteasy_area) as streeteasy_areas,
        median(area_rents.rent_latest)     as rent_latest,
        median(area_rents.rent_12m_median) as rent_12m_median
    from crosswalk
    left join area_rents
        on crosswalk.streeteasy_area = area_rents.area_name
    group by crosswalk.nta_code
),

-- The 80 rental buildings with no NTA can't be placed, so they drop out here.
buildings as (
    select
        nta_code,
        count(*)                    as building_count,
        avg(has_elevator::integer)  as elevator_share,     -- true counts as 1, false as 0
        median(yearbuilt)           as median_yearbuilt,   -- median() skips NULL (unknown) years
        median(unitsres)            as median_unitsres
    from {{ ref('dim_building') }}
    where nta_code is not null
    group by nta_code
),

-- median() returns a double (the median of 1 and 2 is 1.5), so the medians
-- are rounded to whole dollars, years and units here.
final as (
    select
        ntas.nta_code,
        ntas.nta_name,
        ntas.borough,
        ntas.nta_type,
        nta_rents.streeteasy_areas,
        latest_month.month                          as rent_latest_month,
        round(nta_rents.rent_latest)::integer       as rent_latest,
        round(nta_rents.rent_12m_median)::integer   as rent_12m_median,
        coalesce(buildings.building_count, 0)       as building_count,
        round(buildings.elevator_share, 3)          as elevator_share,
        round(buildings.median_yearbuilt)::integer  as median_yearbuilt,
        round(buildings.median_unitsres)::integer   as median_unitsres
    from ntas
    cross join latest_month
    left join nta_rents
        on ntas.nta_code = nta_rents.nta_code
    left join buildings
        on ntas.nta_code = buildings.nta_code
)

select * from final

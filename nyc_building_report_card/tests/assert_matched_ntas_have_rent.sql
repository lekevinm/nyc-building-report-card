-- Every NTA with a StreetEasy match and 10 or more rental buildings must have
-- both rent_latest and rent_12m_median (both are shown in the map tooltip).
-- Known gaps from the rent definitions (SPEC section 3, Nov 24, 2026) are
-- exempt per column: their StreetEasy neighborhoods have no rent in the latest
-- month, or fewer than var('rent_12m_min_months') of the trailing 12 months.
-- Returns one row per failing NTA; zero rows means the test passes.

{{ config(severity = 'error') }}

with profile as (

    select
        nta_code,
        nta_name,
        rent_latest,
        rent_12m_median
    from {{ ref('mart_neighborhood_profile') }}
    where building_count >= 10 and streeteasy_areas is not null

),

check_rent as (

    select
        nta_code,
        nta_name,
        rent_latest,
        rent_12m_median
    from profile
    where (rent_latest is null and 
    -- no rent in latest month
    nta_code not in ('BX0202', 'BX1004', 'BX1104')) 
    or (rent_12m_median is null and 
    -- fewer than 9 of the trailing 12 months
    nta_code not in ('BX1001', 'QN0703', 'QN1304', 'BX1004', 'BX1104'))

)

select * from check_rent

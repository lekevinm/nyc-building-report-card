-- One row per StreetEasy area per month, for the Tableau time-series charts.
-- Kept at StreetEasy's own grain, not NTA, so an area mapped to several NTAs
-- doesn't repeat (SPEC section 3).
-- Design calls by Kevin (Nov 25, 2026):
--   all 182 areas stay in: 176 neighborhoods, 5 boroughs and the NYC city row
--     (filter with area_type).
--   months with no rent stay as rows with a NULL rent, so every area has all
--     202 months and the row 12 back is always the same month a year earlier.
-- Drafted by Claude.

with rents as (
    select
        area_month_id,
        area_name,
        area_type,
        borough,
        month,
        median_asking_rent
    from {{ ref('stg_streeteasy__rents') }}
)

select * from rents

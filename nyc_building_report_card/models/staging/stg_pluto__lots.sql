with source as (
    select * from {{ source('raw', 'raw_pluto') }}
),

renamed as (
    select
        cast(bbl as bigint) as bbl,
        bldgclass,
        cast(unitsres as bigint) as unitsres,
        cast(numfloors as double) as numfloors,
        IF(cast(yearbuilt as bigint) = 0, NULL, cast(yearbuilt as bigint)) as yearbuilt,
        cast(latitude as double) as latitude,
        cast(longitude as double) as longitude
    from source
)

select * from renamed
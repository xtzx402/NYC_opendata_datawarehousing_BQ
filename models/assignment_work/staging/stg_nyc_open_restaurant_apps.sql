-- One row per service request

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           objectid,
           time_of_submission,
           zip,
           borough,
           business_address,
           street,
           latitude,
           longitude,
           qualify_alcohol
       ),

       -- Identifiers
       CAST(objectid AS STRING) AS objectid,

       -- Date/Time
       CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,
       CAST(closed_date AS TIMESTAMP) AS closed_date,

       --qualify_alcohol
       CASE 
            WHEN LOWER(TRIM(qualify_alcohol)) = 'yes' THEN TRUE 
            ELSE FALSE 
        END AS qualify_alcohol,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
           ELSE LPAD(TRIM(CAST(zip AS STRING)), 5, '0')
       END AS zip,

       CAST(business_address AS STRING) AS business_address,
       CAST(street AS STRING) AS street,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at
   FROM source

   -- Filters
   WHERE objectid IS NOT NULL
   AND time_of_submission IS NOT NULL
   AND borough IS NOT NULL

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY time_of_submission DESC) = 1
)

SELECT * FROM cleaned

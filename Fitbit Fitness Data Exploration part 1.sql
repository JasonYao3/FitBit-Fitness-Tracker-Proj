/*

Fitbit Data Exploration Part 1

By: Jason Yao

Skills used: Joins, CTE's, Case when, Aggregate Functions, Windows Functions, Creating Views, Converting Data Types

*/

SELECT * FROM daily_activity;

-- Change column data type
ALTER TABLE daily_activity
ALTER COLUMN activity_date date;

-- Check data integrity
-- not everyone has record for the entire period
SELECT 
    id, COUNT(activity_date) AS num_recorded_days
FROM
    daily_activity
GROUP BY id
ORDER BY num_recorded_days DESC;


-- Average steps, distance, calories, active
SELECT 
    id, activity_date,
    ROUND(AVG(total_steps), 1) AS avg_steps,
    ROUND(AVG(total_distance), 1) AS avg_distance,
    ROUND(AVG(calories), 1) AS avg_calories,
    ROUND(AVG(sedentary_minutes), 1) AS avg_sedentary_time,
    ROUND(AVG(very_active_minutes) / 60, 1) AS avg_very_active_time,
    ROUND(AVG(very_active_minutes + fairly_active_minutes + lightly_active_minutes) / 60,
            1) AS avg_active_time,
    ROUND(AVG(very_active_minutes + fairly_active_minutes + lightly_active_minutes),
            1) AS avg_active_time_min,
    COUNT(activity_date) AS days
FROM
    daily_activity
GROUP BY id , activity_date;


-- Looking at the running total of steps and distance for each person
SELECT 
	id, activity_date, total_steps, 
	SUM(total_steps) OVER(PARTITION BY id ORDER BY activity_date) AS running_total_steps,
	ROUND(total_distance,1) AS total_distance,
	ROUND(SUM(total_distance) OVER(PARTITION BY id ORDER BY activity_date),1) AS running_total_distance
FROM daily_activity;

-- Looking at the 3 days moving average of steps, distance, calories and active for each person
SELECT id, activity_date, total_steps,
	ROUND(AVG(total_steps) OVER(PARTITION BY id ORDER BY activity_date
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),0)
	AS ma_steps_3day,
	ROUND(total_distance,1) AS total_distance,
	ROUND(AVG(total_distance) OVER(PARTITION BY id ORDER BY activity_date
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
	AS ma_distance_3day,
	calories,
	ROUND(AVG(calories) OVER(PARTITION BY id ORDER BY activity_date
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
	AS ma_calories_3day,
	(very_active_minutes + fairly_active_minutes + lightly_active_minutes) AS total_active_minutes,
	ROUND(AVG(very_active_minutes + fairly_active_minutes + lightly_active_minutes) OVER(PARTITION BY id ORDER BY activity_date
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
	AS ma_active_3day
FROM daily_activity;


-- Looking at total active time, total sedentary time, active time vs sedentary time, and percentage of active time and sedentary time vs the entire day
SELECT 
    id, activity_date,
    (very_active_minutes + fairly_active_minutes + lightly_active_minutes) AS total_active_minutes,
    sedentary_minutes,
    ROUND((very_active_minutes + fairly_active_minutes + lightly_active_minutes) / NULLIF(sedentary_minutes, 0) * 100,
            1) AS active_vs_sedentary,
    ROUND((very_active_minutes + fairly_active_minutes + lightly_active_minutes) / 1440 * 100,
            1) AS percent_active,
    ROUND(sedentary_minutes / 1440 * 100, 1) AS percent_sedentary
FROM
    daily_activity
-- order by active_vs_sedentary

-- Total calories burned vs total steps taken
SELECT 
    id, activity_date, total_steps, calories,
    ROUND(calories / NULLIF(total_steps, 0) * 100,
            1) AS calories_vs_steps
FROM
    daily_activity
WHERE
    calories != 0;

-- Using CTE to perform calculation on the daily percent change in calories burned
With calories_lag AS (
SELECT id, activity_date, calories ,
	LAG(calories) OVER(PARTITION BY id ORDER BY activity_date) AS previous_day_calories
FROM daily_activity
),
calories_percent_change AS (
SELECT *, 
COALESCE(ROUND((calories - previous_day_calories) / previous_day_calories * 100,0),0) AS percent_change
FROM calories_lag
)
SELECT *,
	CASE 
		WHEN percent_change > 0 THEN 'increase'
		WHEN percent_change < 0 THEN 'decrease'
		ELSE 'no change'
	END AS trend
FROM calories_percent_change;

-- Using CTE to find the highest number of distance per day
WITH highest_distance_ AS (
SELECT 
	id, 
	activity_date, 
	ROUND(total_distance,1) AS total_distance,
	RANK() OVER(PARTITION BY activity_date ORDER BY total_distance DESC) AS rank_highest_distance
FROM daily_activity
)
SELECT 
    id, activity_date, total_distance
FROM
    highest_distance_
WHERE
    rank_highest_distance = 1;

-- Change column data type
ALTER TABLE sleep_day
ALTER COLUMN sleep_day date;

-- Looking at the average sleeping time in minutes by the number of days recorded.
SELECT 
    id,
    SUM(total_minutes_asleep) AS total_sleep_min,
    COUNT(sleep_day) AS recorded_days,
    ROUND(AVG(total_minutes_asleep), 1) AS avg_sleep_min
FROM
    sleep_day
GROUP BY id
ORDER BY avg_sleep_min DESC;

-- Using CTE to find the daily percent change in sleeping time
WITH sleep_lag AS (
SELECT id, sleep_day, total_minutes_asleep ,
	LAG(total_minutes_asleep) OVER(PARTITION BY id ORDER BY sleep_day) AS previous_day_sleep
FROM sleep_day
),
sleep_percent_change AS (
SELECT *, 
COALESCE(ROUND((total_minutes_asleep - previous_day_sleep) / previous_day_sleep * 100,0),0) AS percent_change
FROM sleep_lag
)
SELECT *,
	CASE 
		WHEN percent_change > 0 THEN 'increase'
		WHEN percent_change < 0 THEN 'decrease'
		ELSE 'no change'
	END as trend
FROM sleep_percent_change;

-- Looking at the percentage of people actually sleeping when they are in bed
SELECT 
    id,
    sleep_day,
    total_minutes_asleep,
    total_time_in_bed,
    ROUND((total_minutes_asleep / total_time_in_bed) * 100,
            1) AS percent_sleep_in_bed
FROM
    sleep_day
ORDER BY percent_sleep_in_bed;

SELECT * FROM weight;

-- Change column data type
ALTER TABLE weight
ALTER COLUMN date date;

-- Pivot bmi into four categories: underweight, normal weight, overweight, and obesity
SELECT 
    id,
    MAX(CASE
        WHEN bmi < 18.5 THEN ROUND(bmi, 1)
    END) AS underweight,
    MAX(CASE
        WHEN bmi >= 18.5 AND bmi <= 24.9 THEN ROUND(bmi, 1)
    END) AS normal_weight,
    MAX(CASE
        WHEN bmi >= 25 AND bmi <= 29.9 THEN ROUND(bmi, 1)
    END) AS overweight,
    MAX(CASE
        WHEN bmi >= 30 THEN ROUND(bmi, 1)
    END) AS obesity
FROM
    weight
GROUP BY id
ORDER BY normal_weight DESC;

-- Using CTE to look at the weight difference for each person by the (last day recorded - first day recorded).
WITH weight_diff AS (
SELECT DISTINCT id,
	MIN(DATE) OVER (PARTITION BY id) AS first_date_time,
	MAX(DATE) OVER (PARTITION BY id) AS last_date_time,
	FIRST_VALUE(weight_pounds) OVER (PARTITION BY id ORDER BY date) AS first_weight_pounds,
	FIRST_VALUE(weight_pounds) OVER (PARTITION BY id ORDER BY date DESC) AS last_weight_pounds
FROM weight
)
SELECT id,
    first_date_time AS first_date_time,
	last_date_time  AS last_date_time,
	ROUND(first_weight_pounds,1) AS first_weight_pounds,
	ROUND(last_weight_pounds,1) AS last_weight_pounds,
	ABS(DATEDIFF(DAY, last_date_time, first_date_time)) AS day_diff,
	ROUND(last_weight_pounds - first_weight_pounds,1) AS weight_diff_pounds
FROM weight_diff
WHERE last_date_time > first_date_time
ORDER BY weight_diff_pounds DESC;


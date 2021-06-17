/*

Fitbit Data Exploration

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

-- Looking at hourly data

-- Creating View to have hourly data join together
-- DROP VIEW IF EXISTS hourly_activity;
CREATE VIEW hourly_activity AS
    SELECT 
        s.id,
        CAST(s.hour AS DATETIME) AS TIME,
        DATENAME(DW, s.hour) AS day_of_week,
        (CASE
            WHEN
                DATENAME(DW, s.hour) = 'Saturday'
                    OR DATENAME(DW, s.hour) = 'Sunday'
            THEN
                'weekend'
            ELSE 'weekday'
        END) AS day_of_week_type,
        s.steps, i.intensities, i.avg_intensity, c.calories
    FROM
        steps_hourly s
            INNER JOIN
        intensities_hourly i ON s.id = i.id AND s.hour = i.hour
            INNER JOIN
        calories_hourly c ON s.id = c.id AND s.hour = c.hour;

-- Looking at steps, intensities and calories by weekdays vs weekends
SELECT id,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekday' THEN steps END ),0) AS steps_weekday,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekend' THEN steps END ),0) AS steps_weekend,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekday' THEN intensities END ),0) AS intensities_weekday,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekend' THEN intensities END ),0) AS intensities_weekend,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekend' THEN calories END ),0) AS calories_weekend,
	ROUND(AVG(CASE WHEN day_of_week_type = 'weekend' THEN calories END ),0) AS calories_weekend
FROM hourly_activity
GROUP BY id;

-- Looking at most active hour
SELECT 
	DATEPART(hour, time) AS hour, ROUND(AVG(calories),0) AS avg_calories
FROM hourly_activity
GROUP BY DATEPART(hour, time)
ORDER BY avg_calories DESC;

-- Looking at calories burned by day of week
SELECT 
	DATEPART(hour, time) AS hour, 
	ROUND(AVG(CASE WHEN day_of_week = 'Monday' THEN calories END),0) Monday,
	ROUND(AVG(CASE WHEN day_of_week = 'Tuesday' THEN calories END),0) Tuesday,
	ROUND(AVG(CASE WHEN day_of_week = 'Wednesday' THEN calories END),0) Wednesday,
	ROUND(AVG(CASE WHEN day_of_week = 'Thursday' THEN calories END),0) Thursday,
	ROUND(AVG(CASE WHEN day_of_week = 'Friday' THEN calories END),0) Friday,
	ROUND(AVG(CASE WHEN day_of_week = 'Saturday' THEN calories END),0) Saturday,
	ROUND(AVG(CASE WHEN day_of_week = 'Sunday' THEN calories END),0) Sunday
FROM hourly_activity
GROUP BY DATEPART(hour, time);


-- Looking at the running total of steps, intensities and calories for each person
SELECT 
	id, time, steps, 
	SUM(steps) OVER(PARTITION BY id ORDER BY TIME) AS running_total_steps,
	intensities,
	SUM(intensities) OVER(PARTITION BY id ORDER BY TIME) AS running_total_intensities,
	calories,
	SUM(calories) OVER(PARTITION BY id ORDER BY TIME) AS running_total_calories
FROM hourly_activity;

-- Creating View to store data for later visualizations
-- group by average heartrate to hourly 
-- not enough data for these 2 people
DROP VIEW IF EXISTS hourly_summary; 

CREATE VIEW hourly_summary AS
	WITH heartrate_by_hour AS(
SELECT 
    id,
    YEAR(time) AS year_time,
    MONTH(time) AS month_time,
    DAY(time) day_time,
    DATEPART(hour, time) AS hour_time,
    ROUND(AVG(heartbeat), 0) AS avg_hearrate
FROM
    heartrate_seconds
GROUP BY id , YEAR(time) , MONTH(time) , DAY(time) , DATEPART(hour, time)
),
heartrate_date AS (
SELECT 
	id, 
	CAST(CONCAT(year_time, '-', month_time, '-', day_time, ' ', hour_time, ':00:000') AS datetime) AS date, 
	avg_hearrate 
FROM 
	heartrate_by_hour)
SELECT 
	ha.*, hd.avg_hearrate 
FROM 
	heartrate_date AS hd
		INNER JOIN 
	hourly_activity ha ON hd.id = ha.id AND hd.date = ha.time
WHERE hd.id NOT IN ('2026352035', '5553957443');
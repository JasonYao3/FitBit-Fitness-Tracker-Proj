/*

Fitbit Data Exploration Part 2

By: Jason Yao

Skills used: Joins, CTE's, Case when, Aggregate Functions, Windows Functions, Creating Views, Converting Data Types

*/

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
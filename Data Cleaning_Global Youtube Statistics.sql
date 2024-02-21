
-- DATA CLEANING

/* Upon investigation of the dataset in Excel, it seems that there are discrepancies 
in both the country and uploads column when compared with the data in the respective YouTube channel.
2024-01-02: manually updated the country column
2024-01-03: manually updated the uploads column */

/* Also updated the numerical values with ',' which will be considered as strings. */

SELECT * FROM global_youtube_statistics


----------------------------------------------------------------------------------------------------------------------------------
-- 1. Clean country and abbrevation columns
-- To check for misspellings in country and abbreviation


SELECT DISTINCT TRIM(country), TRIM(abbreviation)
FROM my_project.global_youtube_statistics;


-- To eliminate nan values


SELECT `rank`, youtuber, title, country, abbreviation
FROM my_project.global_youtube_statistics
WHERE
	country = 'nan' OR
    abbreviation = 'nan';

UPDATE my_project.global_youtube_statistics AS GYS
RIGHT OUTER JOIN my_project.country_abbreviation AS Abbrev
/* country_abbreviation.csv is generated from chatgpt */
	ON GYS.country = Abbrev.country
SET GYS.abbreviation = Abbrev.abbreviation
WHERE youtuber IS NOT NULL;
    
UPDATE my_project.global_youtube_statistics
SET abbreviation = 'KR'
WHERE country = 'South Korea';



----------------------------------------------------------------------------------------------------------------------------------
-- 2. Clean category column
/* To update nan values in category column, its channel type will be considered.
Based on the description of channel type in <https://www.kaggle.com/datasets/nelgiriyewithana/global-youtube-statistics-2023>,
this column should have stated whether the YouTube channel is individual or brand.
But in the dataset, it is more of a concise version of the category column.
Therefore, the channel type will not be included in the cleaned version of the dataset. */

-- To determine the unique values of category and channel type columns


SELECT DISTINCT TRIM(category)
FROM my_project.global_youtube_statistics;
    
SELECT DISTINCT TRIM(channel_type)
FROM my_project.global_youtube_statistics;


-- To eliminate nan values in category column


UPDATE my_project.global_youtube_statistics
SET category = channel_type
WHERE category = 'nan';

UPDATE my_project.global_youtube_statistics
SET category =
	(CASE
		WHEN youtuber = 'News' THEN 'News & Politics'
		WHEN youtuber = 'Busy Fun Ltd' THEN 'Comedy'
		WHEN youtuber = 'Live' THEN 'People & Blogs'
    END)
WHERE youtuber IN ('News', 'Busy Fun Ltd', 'Live');


-- To make unique values consistent after eliminating nan values


UPDATE my_project.global_youtube_statistics
SET category =
	(CASE category
		WHEN category = 'Games' THEN 'Gaming'
        WHEN category = 'Howto' THEN 'Howto & Style'
        WHEN category = 'Tech' THEN 'Science & Technology'
        WHEN category = 'Film' THEN 'Film & Animation'
        WHEN category = 'People' THEN 'People & Blogs'
	END)
WHERE category IN ('Games', 'Howto', 'Tech', 'Film', 'People');



----------------------------------------------------------------------------------------------------------------------------------
-- 3. Clean created_month, created_date, and created_year columns
-- To eliminate nan values


SELECT `rank`, youtuber, title, created_month, created_date, created_year
FROM my_project.global_youtube_statistics
WHERE 
	created_year = 'nan' OR
	created_month = 'nan' OR 
    created_date = 'nan';

UPDATE my_project.global_youtube_statistics
SET created_month = 
	(CASE
		WHEN youtuber = 'Chris Brown' THEN 'Dec'
        WHEN youtuber = 'Good Mythical Morning' THEN 'Sep'
        WHEN youtuber = 'The Game Theorists' THEN 'Aug'
        WHEN youtuber = 'LEGENDA FUNK' THEN 'May'
        WHEN youtuber = 'Harry Styles' THEN 'Mar'
	END),
    
    created_date = 
	(CASE
		WHEN youtuber = 'Chris Brown' THEN '21'
        WHEN youtuber = 'Good Mythical Morning' THEN '17'
        WHEN youtuber = 'The Game Theorists' THEN '23'
        WHEN youtuber = 'LEGENDA FUNK' THEN '11'
        WHEN youtuber = 'Harry Styles' THEN '9'
	END),
    
    created_year = 
	(CASE
		WHEN youtuber = 'Chris Brown' THEN '2006'
        WHEN youtuber = 'Good Mythical Morning' THEN '2008'
        WHEN youtuber = 'The Game Theorists' THEN '2009'
        WHEN youtuber = 'LEGENDA FUNK' THEN '2013'
        WHEN youtuber = 'Harry Styles' THEN '2017'
	END)
WHERE youtuber IN ('Chris Brown', 'Good Mythical Morning', 'The Game Theorists', 'LEGENDA FUNK', 'Harry Styles');


-- To combine creation year, month, and date to a date format


ALTER TABLE my_project.global_youtube_statistics
ADD date_joined DATE;

UPDATE my_project.global_youtube_statistics AS GYS
RIGHT OUTER JOIN my_project.months AS Months
	ON GYS.created_month = Months.`month`
SET date_joined = CONCAT_WS('-', GYS.created_year, Months.month_in_numbers, GYS.created_date);
/* months.csv is manually created in Excel to convert months(strings) into numerical values */



----------------------------------------------------------------------------------------------------------------------------------
-- 4. Convert numerical values from strings to integer
-- To check nan values in columns with numerical values


SELECT *
FROM my_project.global_youtube_statistics
WHERE
	subscribers = 'nan' OR 
    video_views = 'nan' OR
    uploads = 'nan' OR
    video_views_rank = 'nan' OR
    country_rank = 'nan' OR
    channel_type_rank = 'nan' OR
    video_views_for_the_last_30_days = 'nan' OR
    lowest_monthly_earnings = 'nan' OR
    highest_monthly_earnings = 'nan' OR
    lowest_yearly_earnings = 'nan' OR
    highest_yearly_earnings = 'nan' OR
    subscribers_for_last_30_days = 'nan';
    
    
-- Checking the only columns which can be updated if searched on Youtube


SELECT *
FROM my_project.global_youtube_statistics
WHERE
	subscribers = 'nan' OR 
    video_views = 'nan' OR
    uploads = 'nan';
/* no nan values */


-- To convert nan values to null


UPDATE 
	my_project.global_youtube_statistics
SET 
    video_views_rank = NULLIF(video_views_rank, 'nan'),
    country_rank = NULLIF(country_rank, 'nan'),
    channel_type_rank = NULLIF(channel_type_rank, 'nan'),
    video_views_for_the_last_30_days = NULLIF(video_views_for_the_last_30_days, 'nan'),
    lowest_monthly_earnings = NULLIF(lowest_monthly_earnings, 'nan'),
    highest_monthly_earnings = NULLIF(highest_monthly_earnings, 'nan'),
    lowest_yearly_earnings = NULLIF(lowest_yearly_earnings, 'nan'),
    highest_yearly_earnings = NULLIF(highest_yearly_earnings, 'nan'),
    subscribers_for_last_30_days = NULLIF(subscribers_for_last_30_days, 'nan');
    
    
-- To convert strings to integers


ALTER TABLE my_project.global_youtube_statistics
MODIFY subscribers INTEGER, 
MODIFY video_views BIGINT, 
MODIFY uploads INTEGER, 
MODIFY video_views_rank INTEGER, 
MODIFY country_rank INTEGER, 
MODIFY channel_type_rank INTEGER, 
MODIFY video_views_for_the_last_30_days BIGINT, 
MODIFY lowest_monthly_earnings INTEGER, 
MODIFY highest_monthly_earnings INTEGER, 
MODIFY lowest_yearly_earnings INTEGER, 
MODIFY highest_yearly_earnings INTEGER, 
MODIFY subscribers_for_last_30_days INTEGER;


-- Updating the error in row 736


SELECT *
FROM my_project.global_youtube_statistics
WHERE `rank` = 736;

UPDATE 
	my_project.global_youtube_statistics
SET 
    video_views_rank = NULLIF(video_views_rank, '');
    


----------------------------------------------------------------------------------------------------------------------------------
-- 5. Prepare the dataset for Tableau
-- To only include columns needed for data analysis 


SELECT `rank`, youtuber, subscribers, video_views, uploads, category, country, abbreviation,
    video_views_for_the_last_30_days, subscribers_for_last_30_days, lowest_monthly_earnings, highest_monthly_earnings, lowest_yearly_earnings, highest_yearly_earnings,
	created_year, created_month, created_date, date_joined
FROM my_project.global_youtube_statistics;


-- To exclude channels with no earnings data


SELECT `rank`, youtuber, subscribers, video_views, uploads, category, country, abbreviation,
    video_views_for_the_last_30_days, subscribers_for_last_30_days, lowest_monthly_earnings, highest_monthly_earnings, lowest_yearly_earnings, highest_yearly_earnings,
	created_year, created_month, created_date, date_joined
FROM my_project.global_youtube_statistics
WHERE lowest_monthly_earnings != 0 AND
	highest_monthly_earnings != 0 AND
	lowest_yearly_earnings != 0 AND
    highest_yearly_earnings != 0;
    

-- To list YouTube channels with no earnings data


SELECT `rank`, youtuber, lowest_monthly_earnings, highest_monthly_earnings, lowest_yearly_earnings, highest_yearly_earnings
FROM my_project.global_youtube_statistics
WHERE lowest_monthly_earnings = 0 or
	highest_monthly_earnings = 0 or
	lowest_yearly_earnings = 0 or
    highest_yearly_earnings = 0;
    
    

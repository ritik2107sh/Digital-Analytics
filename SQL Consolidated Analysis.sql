use DigitalAnalytics;

--DATA CLEANING AND PROCESSING
UPDATE website_sessions
SET utm_source = 'organic_search'
WHERE utm_source = 'null' AND http_referer <> 'null'
;

UPDATE website_sessions
SET utm_source = 'direct_type-in'
WHERE utm_source = 'null' AND http_referer = 'null'
;
--------------------------------------------------------ANALYSIS------------------------------------------------------------
--Q1. Finding Top Traffic Sources: What is the breakdown of sessions by UTM source, campaign,
--and referring domain up to April 12, 2012. 

SELECT 
    utm_source,
    utm_campaign,
    http_referer,
    COUNT(website_session_id) AS session_count
FROM 
    website_sessions
WHERE 
    created_at <= '2012-04-12'
GROUP BY 
    utm_source,
    utm_campaign,
    http_referer
ORDER BY 
    session_count DESC;
------------------------------------------------------------------------------------------------------------------

--Q2 Traffic Conversion Rates: Calculate conversion rate (CVR) from sessions to order. 
--If CVR is 4% >=, then increase bids to drive volume, otherwise reduce bids. 
--(Filter sessions < 2012-04-12, utm_source = gsearch and utm_campaign = nonbrand) 

-- Step 1: Calculate the total number of sessions
WITH SessionData AS (
    SELECT 
        COUNT(*) AS total_sessions
    FROM 
        website_sessions
    WHERE 
        created_at < '2012-04-12'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
),
-- Step 2: Calculate the total number of orders
OrderData AS (
    SELECT 
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        orders o
    JOIN 
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE 
        ws.created_at < '2012-04-12'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
)
-- Step 3: Calculate the conversion rate (CVR)
SELECT 
    sd.total_sessions,
    od.total_orders,
    ROUND(CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100,2) AS 'conversion_rate(%)',
    CASE 
        WHEN CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100 >= 4 THEN 'Increase bids'
        ELSE 'Reduce bids'
    END AS bidding_strategy
FROM 
    SessionData sd,
    OrderData od;
---------------------------------------------------------------------------------------------------------------------

--Q3. Traffic Source Trending: After bidding down on Apr 15, 2012, what is the trend and impact on sessions 
--for gsearch nonbrand campaign? Find weekly sessions before 2012-05-10.

SELECT 
	DATEADD(DAY,1-DATEPART(WEEKDAY, ws.created_at),CAST(ws.created_at AS DATE)) AS week_start_date,
    COUNT(ws.website_session_id) AS weekly_sessions,
	COUNT(o.order_id) AS orders_count,
	FORMAT(COUNT(o.order_id)*100.0/COUNT(*), '0.00') AS 'CVR%'
FROM 
    website_sessions ws
	LEFT JOIN orders o
	ON ws.website_session_id = o.website_session_id
WHERE 
    ws.created_at < '2012-05-10'
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY 
    DATEADD(DAY,1-DATEPART(WEEKDAY, ws.created_at),CAST(ws.created_at AS DATE))
ORDER BY 
    week_start_date;
----------------------------------------------------------------------------------------------------------------------

--Q4. Traffic Source Bid Optimization: What is the conversion rate from session to order by device type? 

-- Step 1: Calculate the total number of sessions by device type
WITH SessionData AS (
    SELECT 
        device_type,
        COUNT(*) AS total_sessions
    FROM 
        website_sessions
	WHERE 
		created_at < '2012-05-11'
		AND utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        device_type
),
-- Step 2: Calculate the total number of orders by device type
OrderData AS (
    SELECT 
        ws.device_type,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        [orders] o
    JOIN 
        website_sessions ws ON o.website_session_id = ws.website_session_id
	WHERE 
		o.created_at < '2012-05-11'
		AND ws.utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        ws.device_type
)
-- Step 3: Calculate the conversion rate (CVR) by device type
SELECT 
    sd.device_type,
    sd.total_sessions,
    od.total_orders,
    CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100 AS 'conversion_rate(%)'
FROM 
    SessionData sd
LEFT JOIN 
    OrderData od ON sd.device_type = od.device_type
ORDER BY 
    'conversion_rate(%)' DESC;
--------------------------------------------------------------------------------------------------------------------------

--Q5. Traffic Source Segment Trending: After bidding up on desktop channels on 2012-05-19, 
--what is the weekly session trend for both desktop and mobile?

-- Step 1: Calculate weekly sessions by device type
WITH WeeklySessions AS (
    SELECT 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
		sum(case when device_type = 'desktop' then 1 else 0 end) desktop_sessions,
		sum(case when device_type = 'mobile' then 1 else 0 end) mobile_sessions,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
		created_at >= ' 2012-04-15' and created_at < '2012-06-19'
		AND utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
)
-- Step 2: Select the results and label the periods
SELECT 
    week_start_date,
    desktop_sessions,
	mobile_sessions
FROM 
    WeeklySessions
ORDER BY 
    week_start_date;

----------------------------------------------------------------------------------------------------------------------

--Q6 Identifying Top Website Pages: What are the most viewed website pages ranked by session volume? 

SELECT 
    pageview_url,
    COUNT(DISTINCT website_session_id) AS session_volume
FROM 
    website_pageviews
WHERE 
	created_at < '2012-06-09'
GROUP BY 
    pageview_url
ORDER BY 
    session_volume DESC;
--------------------------------------------------------------------------------------------------------------------

--Q7 Identifying Top Entry Pages: Pull a list of top entry pages
with A as(
select website_session_id, min(created_at) as start_time 
from website_pageviews
where created_at < '2012-06-12'
group by website_session_id),
C as 
(
select B.website_session_id, pageview_url 
from website_pageviews B
inner join A
on B.website_session_id = A.website_session_id
and B.created_at = A.start_time
)
select pageview_url, count(website_session_id) as count_of_sessions 
from C
group by pageview_url
order by count_of_sessions desc;
---------------------------------------------------------------------------------------------------------------------

--Q8. Calculating Bounce Rates: Pull out the bounce rates for traffic landing on 
--home page by sessions, bounced sessions and bounce rate?

-- Step 1: Find when /lander-1 was first displayed and limit by date
WITH FirstPageViews AS (
    SELECT website_session_id, MIN(created_at) AS start_time
    FROM website_pageviews
    WHERE pageview_url = '/home'
    GROUP BY website_session_id
),
-- Step 2: Filter sessions to include only those after '2012-06-19' and before '2012-07-28'
FilteredSessions AS (
        SELECT website_session_id, start_time
    FROM FirstPageViews
    WHERE start_time < '2012-06-14'
),
-- Step 3: Count page views per session
PageViewCounts AS (
	SELECT website_session_id, COUNT(*) AS page_view_count
    FROM website_pageviews
    WHERE website_session_id IN (SELECT website_session_id FROM FilteredSessions)
    GROUP BY website_session_id
),
-- Identify bounces (sessions with only 1 page view)
BouncedSessions AS (
    SELECT website_session_id
    FROM PageViewCounts
    WHERE page_view_count = 1
),
---- Count total sessions and bounced sessions for /home
SessionCounts AS (
        SELECT
        COUNT(DISTINCT f.website_session_id) AS total_sessions,
        COUNT(DISTINCT b.website_session_id) AS bounced_sessions
    FROM FilteredSessions f
    LEFT JOIN BouncedSessions b
    ON f.website_session_id = b.website_session_id
)
-- Calculate the bounce rate
SELECT
    '/home' AS landing_page,
    total_sessions,
    bounced_sessions,
    (bounced_sessions * 100.0 / total_sessions) AS bounce_rate
FROM SessionCounts;
----------------------------------------------------------------------------------------------------------------------
--Q9 Analyzing Landing Page Tests: What are the bounce rates for \lander-1 and \home in the A/B test conducted 
--by ST for the gsearch nonbrand campaign, considering traffic received by \lander-1 and \home before 
--<2012-07-28 to ensure a fair comparison?

-- Step 1: Find when /lander-1 was first displayed and limit by date
WITH FirstPageViews AS (
    SELECT website_session_id, MIN(created_at) AS start_time
    FROM website_pageviews
    WHERE pageview_url = '/home' 
	and website_session_id in 
	(select website_session_id from website_sessions where utm_source = 'gsearch' and utm_campaign = 'nonbrand')
    GROUP BY website_session_id
),
-- Step 2: Filter sessions to include only those after '2012-06-19' and before '2012-07-28'
FilteredSessions AS (
    SELECT website_session_id, start_time
    FROM FirstPageViews
    WHERE start_time BETWEEN '2012-06-19' AND '2012-07-28'
),
-- Step 3: Count page views per session
PageViewCounts AS (
    SELECT website_session_id, COUNT(*) AS page_view_count
    FROM website_pageviews
    WHERE website_session_id IN (SELECT website_session_id FROM FilteredSessions)
    GROUP BY website_session_id
),
-- Identify bounces (sessions with only 1 page view)
BouncedSessions AS (
    SELECT website_session_id
    FROM PageViewCounts
    WHERE page_view_count = 1
),
-- Count total sessions and bounced sessions for /home
SessionCounts AS (
    SELECT 
	COUNT(DISTINCT f.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions
    FROM FilteredSessions f
    LEFT JOIN BouncedSessions b
    ON f.website_session_id = b.website_session_id
),
-- Step 1: Find when /lander-1 was first displayed and limit by date
FirstPageViews_1 AS (
    SELECT website_session_id, MIN(created_at) AS start_time
    FROM website_pageviews
    WHERE pageview_url = '/lander-1' 
	and website_session_id in 
	(select website_session_id from website_sessions where utm_source = 'gsearch' and utm_campaign = 'nonbrand')
    GROUP BY website_session_id
),
-- Step 2: Filter sessions to include only those after '2012-06-19' and before '2012-07-28'
FilteredSessions_1 AS (
    SELECT website_session_id, start_time
    FROM FirstPageViews_1
    WHERE start_time BETWEEN '2012-06-19' AND '2012-07-28'
),
-- Step 3: Count page views per session
PageViewCounts_1 AS (
    SELECT website_session_id, COUNT(*) AS page_view_count
    FROM website_pageviews
    WHERE website_session_id IN (SELECT website_session_id FROM FilteredSessions_1)
    GROUP BY website_session_id
),
-- Identify bounces (sessions with only 1 page view)
BouncedSessions_1 AS (
    SELECT website_session_id
    FROM PageViewCounts_1
    WHERE page_view_count = 1
),
-- Count total sessions and bounced sessions for /home
SessionCounts_1 AS (
    SELECT
        COUNT(DISTINCT f.website_session_id) AS total_sessions,
        COUNT(DISTINCT b.website_session_id) AS bounced_sessions
    FROM FilteredSessions_1 f
    LEFT JOIN BouncedSessions_1 b
    ON f.website_session_id = b.website_session_id
)
-- Calculate the bounce rate
SELECT
    '/home' AS landing_page,
    total_sessions,
    bounced_sessions,
    (bounced_sessions * 100.0 / total_sessions) AS bounce_rate
FROM SessionCounts

union

SELECT
    '/lander-1' AS landing_page,
    total_sessions,
    bounced_sessions,
    (bounced_sessions * 100.0 / total_sessions) AS bounce_rate
FROM SessionCounts_1;
---------------------------------------------------------------------------------------------------------------

--Q10 Landing Page Trend Analysis: What is the trend of weekly paid gsearch nonbrand campaign traffic on 
--/home and /lander-1 pages since June 1, 2012, along with their respective bounce rates, as requested 
--by ST? Please limit the results to the period between June 1, 2012, and August 31, 2012, based on the 
--email received on August 31, 2021


WITH FirstPageViews AS (
    -- Step 1: Find first page view for each session and limit by date range
    SELECT 
        website_session_id, 
        MIN(website_pageview_id) AS first_pageview_id,
        MIN(created_at) AS session_start_time
    FROM website_pageviews
    WHERE website_session_id in 
	(select website_session_id from website_sessions where created_at >= '2012-06-01' AND created_at <= '2012-08-31'
	and utm_source = 'gsearch' and utm_campaign = 'nonbrand') 
    GROUP BY website_session_id
),
LandingPages AS (
    -- Step 2: Identify landing page of each session (only for /home and /lander-1)
    SELECT 
        A.website_session_id,
        A.first_pageview_id,
        B.pageview_url AS landing_page,
        A.session_start_time
    FROM FirstPageViews A
    INNER JOIN website_pageviews B ON A.first_pageview_id = B.website_pageview_id
    AND B.pageview_url IN ('/home', '/lander-1')
),
BounceCounts AS (
    -- Step 3: Count page views for each session to identify bounces
    SELECT 
        L.website_session_id,
        L.landing_page,
        L.session_start_time,
        COUNT(*) AS page_view_count
    FROM LandingPages L
    INNER JOIN website_pageviews P ON L.website_session_id = P.website_session_id
    GROUP BY L.website_session_id, L.landing_page, L.session_start_time
),
WeeklySummary AS (
    -- Step 4: Summarize sessions, bounced sessions, and calculate bounce rate by week
    SELECT 
        landing_page,
        DATEADD(week, DATEDIFF(week, 0, session_start_time), 0) AS week_start_date,
        COUNT(*) AS sessions_count,
        SUM(CASE WHEN page_view_count = 1 THEN 1 ELSE 0 END) AS bounced_sessions,
        (SUM(CASE WHEN page_view_count = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS bounce_rate
    FROM BounceCounts
    GROUP BY landing_page, DATEADD(week, DATEDIFF(week, 0, session_start_time), 0)
)
-- Final query to fetch the desired result
SELECT 
    landing_page,
    CONVERT(date, week_start_date) AS week_start_date,
    sessions_count,
    bounced_sessions,
    ROUND(bounce_rate, 2) AS bounce_rate
FROM WeeklySummary
ORDER BY week_start_date, landing_page;
--------------------------------------------------------------------------------------------------------------------

--Q11 Build Conversion Funnels for gsearch nonbrand traffic from /lander-1 to /thank you page: What are the session counts and click 
--percentages for \lander-1, product, mrfuzzy, cart, shipping, billing, and thank you pages from August 5, 2012, to September 5, 
--2012?

WITH RelevantSessions AS (
    SELECT
        website_session_id,
        MIN(created_at) AS first_pageview
    FROM website_pageviews
    WHERE pageview_url = '/lander-1'
    AND website_session_id in (select website_session_id from website_sessions where 
	utm_source = 'gsearch' and utm_campaign = 'nonbrand')
    AND created_at BETWEEN '2012-08-05' AND '2012-09-05'
    GROUP BY website_session_id
),
FunnelSteps AS (
    SELECT
        pv.website_session_id,
        pv.created_at,
        pv.pageview_url,
        CASE
            WHEN pv.pageview_url = '/lander-1' THEN 'lander1_click'
            WHEN pv.pageview_url = '/products' THEN 'product_click'
            WHEN pv.pageview_url = '/the-original-mr-fuzzy' THEN 'mrfuzzy_click'
            WHEN pv.pageview_url = '/cart' THEN 'cart_click'
            WHEN pv.pageview_url = '/shipping' THEN 'shipping_click'
            WHEN pv.pageview_url = '/billing' THEN 'billing_click'
            WHEN pv.pageview_url = '/thank-you-for-your-order' THEN 'thank_you_click'
            ELSE NULL
        END AS funnel_step
    FROM website_pageviews pv
    INNER JOIN RelevantSessions rs ON pv.website_session_id = rs.website_session_id
    WHERE pv.created_at BETWEEN '2012-08-05' AND '2012-09-05'
),
SessionFunnelView AS (
    SELECT
        website_session_id,
        MAX(CASE WHEN funnel_step = 'lander1_click' THEN 1 ELSE 0 END) AS lander1_click,
        MAX(CASE WHEN funnel_step = 'product_click' THEN 1 ELSE 0 END) AS product_click,
        MAX(CASE WHEN funnel_step = 'mrfuzzy_click' THEN 1 ELSE 0 END) AS mrfuzzy_click,
        MAX(CASE WHEN funnel_step = 'cart_click' THEN 1 ELSE 0 END) AS cart_click,
        MAX(CASE WHEN funnel_step = 'shipping_click' THEN 1 ELSE 0 END) AS shipping_click,
        MAX(CASE WHEN funnel_step = 'billing_click' THEN 1 ELSE 0 END) AS billing_click,
        MAX(CASE WHEN funnel_step = 'thank_you_click' THEN 1 ELSE 0 END) AS thank_you_click
    FROM FunnelSteps
    GROUP BY website_session_id
) 
SELECT
    COUNT(website_session_id) AS sessions,
    SUM(product_click) * 100.0 / SUM(lander1_click) AS product_click_percentage,
    SUM(mrfuzzy_click) * 100.0 / SUM(product_click) AS mrfuzzy_click_percentage,
    SUM(cart_click) * 100.0 / SUM(mrfuzzy_click) AS cart_click_percentage,
    SUM(shipping_click) * 100.0 /  SUM(cart_click)
	AS shipping_click_percentage,
    SUM(billing_click) * 100.0 / SUM(shipping_click) AS billing_click_percentage,
    SUM(thank_you_click) * 100.0 / SUM(billing_click) AS thank_you_click_percentage
FROM SessionFunnelView;
---------------------------------------------------------------------------------------------------------------------------
--Qn 12 Analyze Conversion Funnel Tests for /billing vs. new /billing-2 pages: what is the traffic and billing to order conversion rate of 
--both pages new/billing-2 page?

WITH billing_cte AS (
  SELECT 
    s.website_session_id,
    p.pageview_url
  FROM website_sessions s
  JOIN website_pageviews p
    ON s.website_session_id = p.website_session_id
  WHERE p.pageview_url IN ('/billing', '/billing-2')
    AND p.website_pageview_id >= (SELECT MIN(website_pageview_id)
										FROM website_pageviews
										WHERE pageview_url = '/billing-2')
    AND s.created_at < '2012-11-10'
)
SELECT
  b.pageview_url,
  COUNT(DISTINCT b.website_session_id) AS sessions,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(100.0 * COUNT(DISTINCT o.order_id) / COUNT(DISTINCT b.website_session_id), 2) AS session_to_orders_rate
FROM billing_cte b
LEFT JOIN orders o
  ON b.website_session_id = o.website_session_id
GROUP BY b.pageview_url;


---------------------------------------------------------------------------------------------------------------------

--Q13. Analyzing Channel Portfolios: What are the weekly sessions data for both gsearch and bsearch from 
--August 22nd to November 29th? 

SELECT 
	dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date)) week_start_date,
	sum(case when (utm_source = 'gsearch' and utm_campaign = 'nonbrand') then 1 else 0 end) AS gsearch_nonbrand_session,
	sum(case when (utm_source = 'bsearch' and utm_campaign = 'nonbrand') then 1 else 0 end) AS bsearch_nonbrand_session
FROM website_sessions
WHERE 
	created_at > '2012-08-22' 
	AND cast(created_at AS datetime) < '2012-11-29'
GROUP BY  
	dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date))
ORDER BY week_start_date;

---------------------------------------------------------------------------------------------------------------------
--Q14. Comparing Channel Characteristics: What are the mobile sessions data for non-brand campaigns of gsearch and bsearch from 
--August 22nd to November 30th, including details such as utm_source, total sessions, mobile sessions, and the percentage of 
--mobile sessions?

WITH SessionsData AS (
    SELECT
        utm_source,
        COUNT(website_session_id) AS total_sessions,
        SUM(CASE WHEN device_type = 'mobile' THEN 1 ELSE 0 END) AS mobile_sessions
    FROM website_sessions
    WHERE utm_source IN ('gsearch', 'bsearch')
    AND utm_campaign = 'nonbrand'
    AND created_at BETWEEN '2012-08-22' AND '2012-11-30'
    GROUP BY utm_source
)
SELECT
    utm_source,
    total_sessions,
    mobile_sessions,
    (mobile_sessions * 100.0 / total_sessions) AS mobile_perc
FROM SessionsData;
--------------------------------------------------------------------------------------------------------------------
--Q15. Cross-Channel Bid Optimization: provide the conversion rates from sessions to orders for non-brand campaigns of gsearch and 
--bsearch by device type, for the period spanning from August 22nd to September 18th? Additionally, include details such as device 
--type, utm_source, total sessions, total orders, and the corresponding conversion rates.

WITH SessionData AS (
    SELECT
        ws.device_type,
        ws.utm_source,
        COUNT(ws.website_session_id) AS sessions,
        COUNT(o.order_id) AS orders
    FROM website_sessions ws
    LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
    WHERE ws.utm_source IN ('gsearch', 'bsearch')
    AND ws.utm_campaign = 'nonbrand'
    AND ws.created_at BETWEEN '2012-08-22' AND '2012-09-18'
    GROUP BY ws.device_type, ws.utm_source
)
SELECT
    device_type,
    utm_source,
    sessions,
    orders,
    (orders * 100.0 / sessions) AS conversion_rate
FROM SessionData
ORDER BY device_type, utm_source;
-----------------------------------------------------------------------------------------------------------------------

--Q16. Channel Portfolio Trends: Retrieve the data for gsearch and bsearch non-brand sessions segmented by device type 
--from November 4th to December 22nd? Additionally, include details such as the start date of each week, 
--device type, utm_source, total sessions, bsearch comparison.

WITH cte2 AS (
	SELECT 
		dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date)) week_start_date, 
		sum(case when (utm_source = 'gsearch' and device_type = 'desktop') then 1 else 0 end) gsearch_desktop_sessions,
		sum(case when (utm_source = 'bsearch' and device_type = 'desktop') then 1 else 0 end) bsearch_desktop_sessions,
		sum(case when (utm_source = 'gsearch' and device_type = 'mobile') then 1 else 0 end) gsearch_mobile_sessions,
		sum(case when (utm_source = 'bsearch' and device_type = 'mobile') then 1 else 0 end) bsearch_mobile_sessions
	FROM website_sessions
	WHERE utm_campaign = 'nonbrand' 
	and cast(created_at AS datetime) > '2012-11-04' 
	and cast(created_at AS datetime) < '2012-12-22'
	GROUP BY dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date))
)
SELECT  week_start_date, 
		gsearch_desktop_sessions,
		bsearch_desktop_sessions, 
		round((bsearch_desktop_sessions * 100.0/gsearch_desktop_sessions),2) AS 'bg_desktop_CVR%',
		gsearch_mobile_sessions, 
		bsearch_mobile_sessions,
		round((bsearch_mobile_sessions * 100.0/gsearch_mobile_sessions),2) AS 'bg_mobile_CVR%' 
		from cte2
ORDER BY week_start_date
;

----------------------------------------------------------------------------------------------------------------------

--Q17. Analyzing Free Channels: Could you pull organic search , direct type in and paid brand sessions by month 
--and show those sessions AS a % of paid search non brand? 

WITH cte3 AS (
SELECT  year(created_at) year_, 
		month(created_at) month_, 
		sum(case when utm_campaign = 'nonbrand' then 1 else 0 end) nonbrand_sessions,
		sum(case when utm_campaign = 'brand' then 1 else 0 end) brand_sessions,
		sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer = 'NULL') then 1 else 0 end) direct_sessions,
		sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer != 'NULL') then 1 else 0 end) organic_sessions
FROM website_sessions
WHERE year(created_at) = '2012'
GROUP BY  year(created_at), month(created_at)
)
SELECT 
	year_, 
	month_, 
	nonbrand_sessions, 
	brand_sessions, 
	round((brand_sessions* 100.0/nonbrand_sessions),2) brand_per_of_nonbrand, 
	direct_sessions,
	cast(round((direct_sessions * 100.0/nonbrand_sessions),2) AS float) direct_per_of_nonbrand, 
	organic_sessions,
	cast(round((organic_sessions * 100.0/nonbrand_sessions),2) AS float) organic_per_of_nonbrand 
	from cte3
ORDER BY year_, month_;

----------------------------------------------------------------------------------------------------------------------

--Q18. Analyzing Seasonality: Pull out sessions and orders by year, monthly and weekly for 2012?

-- Sessions by year, month
WITH session_data AS (
    SELECT 
        DATEPART(YEAR, created_at) AS year,
        DATEPART(MONTH, created_at) AS month,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
        DATEPART(YEAR, created_at) = 2012
	GROUP BY 
		DATEPART(YEAR, created_at),
        DATEPART(MONTH, created_at) 
  
),
-- no of Orders by year, month, and week
order_data AS (
    SELECT 
        DATEPART(YEAR, created_at) AS year,
        DATEPART(MONTH, created_at) AS month,
        COUNT(order_id) AS order_count
    FROM 
        [orders]
    WHERE 
        DATEPART(YEAR, created_at) = 2012
		GROUP BY 
		DATEPART(YEAR, created_at),
        DATEPART(MONTH, created_at)
)
-- Combining session and order data
SELECT 
    sd.year,
    sd.month,
    sd.session_count,
    od.order_count,
    Format(od.order_count*1.0/sd.session_count,'0.000') AS order_rate
FROM 
    session_data sd
LEFT JOIN 
    order_data od ON sd.year = od.year AND sd.month = od.month
ORDER BY 
    sd.year,
    sd.month;


-- Weekly Sessions 
WITH weekly_session_data AS (
    SELECT 
		DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
        DATEPART(YEAR, created_at) = 2012
	GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
  
),
-- no of Orders by  week
weekly_order_data AS (
    SELECT 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
        COUNT(order_id) AS order_count
    FROM 
        [orders]
    WHERE 
        DATEPART(YEAR, created_at) = 2012
		GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
)
-- Combining session and order data
SELECT 
    sd.week_start_date,
    sd.session_count,
    od.order_count,
	Format(od.order_count*1.0/sd.session_count,'0.000') AS order_rate
FROM 
    weekly_session_data sd
LEFT JOIN 
    weekly_order_data od ON sd.week_start_date = od.week_start_date
ORDER BY 
    sd.week_start_date;

---------------------------------------------------------------------------------------------------------------------

--19. Analyzing Business Patterns: What is the average website session volume,
--categorized by hour of the day and day of the week, between September 15th and November 15th ,2013, 
--excluding holidays to assist in determining appropriate staffing levels for live chat support on the website?  

 
-- Average website session volume categorized by hour of the day and day of the week 
select  
case  
when datepart(weekday, hour_of_day) = 2 then 'monday' 
when datepart(weekday, hour_of_day) = 3 then 'tuesday' 
when datepart(weekday, hour_of_day) = 4 then 'wednesday' 
when datepart(weekday, hour_of_day) = 5 then 'thursday' 
when datepart(weekday, hour_of_day) = 6 then 'friday' 
end as day_of_week, 
datepart(hour, hour_of_day) as hour_of_day, 
avg(session_count) as avg_session_volume 
from ( 
select 
dateadd(hour, datediff(hour, 0, ws.created_at), 0) as hour_of_day, 
count(distinct ws.website_session_id) as session_count 
from  
website_sessions ws 
where  
ws.created_at between '2013-09-15' and '2013-11-15' 
-- exclude Saturdays and Sundays 
and datepart(weekday, ws.created_at) not in (1, 7)  
-- exclude Columbus Day and Veterans Day 
and ws.created_at not in ('2013-10-14', '2013-11-11')  
group by  
dateadd(hour, datediff(hour, 0, ws.created_at), 0) 
) as hourly_sessions 
group by  
case  
when datepart(weekday, hour_of_day) = 2 then 'monday' 
when datepart(weekday, hour_of_day) = 3 then 'tuesday' 
when datepart(weekday, hour_of_day) = 4 then 'wednesday' 
when datepart(weekday, hour_of_day) = 5 then 'thursday' 
when datepart(weekday, hour_of_day) = 6 then 'friday' 
end, 
datepart(hour, hour_of_day) 
order by  
day_of_week, 
hour_of_day 
;

-------------------------------------------------------------------------------------------------------------------------

--20. Product Level Sales Analysis
--Pull monthly trends to date, for number of sales, total revenue and total margin generated.
select
datepart(year, created_at) as yearname,
datepart(mm, created_at) as monthname,
count(distinct order_id) as no_of_orders,
round(sum(price_usd),2) as revenue,
round(sum(price_usd)-sum(cogs_usd),2) as margin
from orders 
group by datepart(year, created_at), datepart(mm, created_at) 
order by yearname, monthname
;

--------------------------------------------------------------------------------------------------------------------------
--Qn.21 monthly order volume, overall conversion rates, revenue per session, and breakdown of sales per product
--for all the time period since april 1,2013. Only for second product launched on 6th jan.

--monthly order volume
select datepart(yyyy, created_at) as yearname,
datepart(mm, created_at) as monthname,
count(distinct order_id) as no_of_orders
from orders
where primary_product_id=2
group by  datepart(mm, created_at),datepart(yyyy, created_at)
;

--revenue per session
select round(sum(price_usd)/count(website_session_id),2) as revenue_per_session_in_USD
from orders
where primary_product_id=2
;

--overall conversion rates
with users_prod2 as
(
select count(distinct user_id) as no_of_users
from orders
where primary_product_id=2
),
total_users as 
(
select count(distinct user_id) as total_no_of_users
from orders
)
select no_of_users*100.0/total_no_of_users as conversion_rate
from users_prod2 
cross join total_users 
;

----------------------------------------------------------------------------------------------------------------------

--Q22. Product Pathing Analysis: What are the clickthrough rates from /products since the new product launch on January 6th 2013,
--by product and compare to the 3 months leading up to launch as a baseline? 

-- Step 1: Find the /products pageviews with time period categorization
WITH products_pageviews AS (
    SELECT 
        website_session_id,
        website_pageview_id,
        created_at,
        CASE 
            WHEN created_at < '2013-01-06' THEN 'A. Pre_Product_2'
            WHEN created_at >= '2013-01-06' THEN 'B. Post_Product_2'
            ELSE 'uh oh...check logic'
        END AS time_period
    FROM website_pageviews
    WHERE created_at BETWEEN '2012-10-06' AND '2013-04-06'
    AND pageview_url = '/products'
),
-- Step 2: Find the next pageview id that occurs after product pageview
sessions_w_next_page_id AS (
    SELECT 
        products_pageviews.time_period,
        products_pageviews.website_session_id,
        MIN(website_pageviews.website_pageview_id) AS min_next_pageview_id
    FROM products_pageviews
    LEFT JOIN website_pageviews 
        ON website_pageviews.website_session_id = products_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id
    GROUP BY products_pageviews.time_period, products_pageviews.website_session_id
),
-- Step 3: Join with next pageview URL
sessions_w_next_pageview_url AS (
    SELECT 
        sessions_w_next_page_id.time_period,
        sessions_w_next_page_id.website_session_id,
        website_pageviews.pageview_url AS next_pageview_url
    FROM sessions_w_next_page_id
    LEFT JOIN website_pageviews 
        ON sessions_w_next_page_id.website_session_id = website_pageviews.website_session_id
        AND sessions_w_next_page_id.min_next_pageview_id = website_pageviews.website_pageview_id
)
-- Step 4: Summarize the data and analyze pre and post periods
SELECT
    time_period,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END) AS FLOAT) / CAST(COUNT(DISTINCT website_session_id) AS FLOAT), 4) AS pct_w_next_pg,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mr_fuzzy,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS FLOAT) / CAST(COUNT(DISTINCT website_session_id) AS FLOAT), 4) AS pct_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS FLOAT) / CAST(COUNT(DISTINCT website_session_id) AS FLOAT), 4) AS pct_to_lovebear
FROM sessions_w_next_pageview_url
GROUP BY time_period;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Q23.Product Conversion Funnels: provide a comparison of the conversion funnels from the product pages to conversion 
--for two products since January 6th, analyzing all website traffic?












----------------------------------------------------------------------------------------------------------------------
--Q24. Cross-Sell Analysis: Analyze the impact of offering customers the option to add a second 
--product on the /cart page, comparing the metrics from the month before the change to the month after? Specifically, 
--in comparing the click-through rate (CTR) from the /cart page, average products per order, average order value (AOV),
--and overall revenue per /cart page view. 

WITH sessions_seeing_cart AS (
    SELECT
        CASE
            WHEN created_at < '2013-09-25' THEN 'A. Pre_Cross_Sell'
            WHEN created_at >= '2013-09-25' THEN 'B. Post_Cross_Sell'
            ELSE 'uh oh... check logic'
        END AS time_period,
        website_session_id AS cart_session_id,
        website_pageview_id AS cart_pageview_id
    FROM website_pageviews
    WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25'
      AND pageview_url = '/cart'
),
cart_sessions_seeing_another_page AS (
    SELECT
        s.time_period,
        s.cart_session_id,
        MIN(w.website_pageview_id) AS pv_id_after_cart
    FROM sessions_seeing_cart s
    LEFT JOIN website_pageviews w ON s.cart_session_id = w.website_session_id
       AND w.website_pageview_id > s.cart_pageview_id
    GROUP BY s.time_period, s.cart_session_id
    HAVING MIN(w.website_pageview_id) IS NOT NULL
),
pre_post_sessions_orders AS (
    SELECT
        s.time_period,
        s.cart_session_id,
        o.order_id,
        o.items_purchased,
        o.price_usd
    FROM sessions_seeing_cart s
    INNER JOIN orders o ON s.cart_session_id = o.website_session_id
)
SELECT
    s.time_period,
    CAST(COUNT(DISTINCT s.cart_session_id) AS FLOAT) AS cart_sessions,
    CAST(SUM(CASE WHEN c.cart_session_id IS NULL THEN 0 ELSE 1 END) AS FLOAT) AS clickthroughs,
    ROUND(SUM(CASE WHEN c.cart_session_id IS NULL THEN 0 ELSE 1 END) / CAST(COUNT(DISTINCT s.cart_session_id) AS FLOAT), 4) AS cart_ctr,
    ROUND(SUM(o.items_purchased) / CAST(SUM(CASE WHEN o.order_id IS NULL THEN 0 ELSE 1 END) AS FLOAT), 4) AS products_per_order,
    ROUND(SUM(o.price_usd) / CAST(SUM(CASE WHEN o.order_id IS NULL THEN 0 ELSE 1 END) AS FLOAT), 4) AS aov, -- average order value
    ROUND(SUM(o.price_usd) / CAST(COUNT(DISTINCT s.cart_session_id) AS FLOAT), 4) AS rev_per_cart_session
FROM sessions_seeing_cart s
LEFT JOIN cart_sessions_seeing_another_page c ON s.cart_session_id = c.cart_session_id
LEFT JOIN pre_post_sessions_orders o ON s.cart_session_id = o.cart_session_id
GROUP BY s.time_period
ORDER BY s.time_period;

----------------------------------------------------------------------------------------------------------------------------------------------------



--25. Portfolio Expansion Analysis: Conduct a pre-post analysis comparing the month before and the month after the launch of the “Birthday Bear” product on December 12th, 2013? Specifically, containing the changes in session-to-order conversion rate, average order value (AOV), products per order, and revenue per session. 

DECLARE @launch_date DATE = '2013-12-12'; 

  
-- Pre-launch period: November 12, 2013 to December 11, 2013 

-- Post-launch period: December 12, 2013 to January 11, 2014 

WITH PreLaunchSessions AS ( 
SELECT 
COUNT(DISTINCT ws.website_session_id) AS session_count, 
COUNT(DISTINCT o.order_id) AS order_count, 
SUM(oi.price_usd) AS total_revenue, 
COUNT(oi.order_item_id) AS total_products 
FROM 
website_sessions ws 
LEFT JOIN  
orders o ON ws.website_session_id = o.website_session_id 
LEFT JOIN  
order_items oi ON o.order_id = oi.order_id 
WHERE 
ws.created_at BETWEEN DATEADD(MONTH, -1, @launch_date) AND DATEADD(DAY, -1, @launch_date) 
),  
PostLaunchSessions AS ( 
SELECT 
COUNT(DISTINCT ws.website_session_id) AS session_count, 
COUNT(DISTINCT o.order_id) AS order_count, 
SUM(oi.price_usd) AS total_revenue, 
COUNT(oi.order_item_id) AS total_products 
FROM 
website_sessions ws 
LEFT JOIN  
orders o ON ws.website_session_id = o.website_session_id 
LEFT JOIN  
order_items oi ON o.order_id = oi.order_id 
WHERE 
ws.created_at BETWEEN @launch_date AND DATEADD(MONTH, 1, @launch_date) 
) 
SELECT  
'Pre-launch' AS period, 
pre.session_count, 
pre.order_count, 
CAST(pre.order_count AS FLOAT) / CAST(pre.session_count AS FLOAT) * 100 AS conversion_rate, 
pre.total_revenue / pre.order_count AS average_order_value, 
CAST(pre.total_products AS FLOAT) / pre.order_count AS products_per_order, 
pre.total_revenue / pre.session_count AS revenue_per_session 
FROM  
PreLaunchSessions pre 
  
UNION ALL 

SELECT  
'Post-launch' AS period, 
post.session_count, 
post.order_count, 
CAST(post.order_count AS FLOAT) / CAST(post.session_count AS FLOAT) * 100 AS conversion_rate, 
post.total_revenue / post.order_count AS average_order_value, 
CAST(post.total_products AS FLOAT) / post.order_count AS products_per_order, 
post.total_revenue / post.session_count AS revenue_per_session 
FROM  
PostLaunchSessions post ;

-----------------------------------------------------------------------------------------------------------------------------------------------

--Qn26. Product Refund rates
--Monthly product refund rates, by product, since sept 16, 2014
select product_name,
datepart(yyyy,o.created_at) as yearly,
datepart(mm,o.created_at) as monthly,
round(sum(refund_amount_usd),2) as refunded_amount,
count(distinct convert(date,r.created_at)) as no_of_days_refunded
from products p
inner join orders o
on p.product_id=o.primary_product_id
inner join order_item_refunds r
on o.order_id=r.order_id
where o.created_at>='2014-09-16 01:31:19.0000000' 
group by product_name,datepart(mm,o.created_at),datepart(yyyy,o.created_at)
;

------------------------------------------------------------------------------------------------------------------------------

--27. Identifying Repeat Visitors: Please pull data on how many of our website visitors come back for another session?2014 to date is good. 

--using the user_id to find any repeat sessions those users had 
with sessions_w_repeats as(                     	 
select  
new_session.user_id, 
session new_session_id, 
w.website_session_id repeat_session_id 
from( 
--subquery for finding new session /first session 
select	
user_id, 
website_session_id session 
from 
website_sessions 
where created_at >= '2014-01-01' and created_at < '2014-11-01' and is_repeat_session=0 
) as new_session 
left join website_sessions as w				 
on  w.user_id=new_session.user_id 
and is_repeat_session=1 and created_at >= '2014-01-01' and created_at < '2014-11-01') 
--grouping repeat sessions and count of users 
select							 
repeat_sessions, 
count(distinct user_id) users 
from (                    
--how many sessions did each user have 
select		 
user_id, 
count(distinct repeat_session_id) as repeat_sessions 
from sessions_w_repeats 
group by user_id) as user_level 
group by repeat_sessions 
order by users desc; 

----------------------------------------------------------------------------------------------------------------------------------------------

--28.Analyzing Repeat Behavior: What is the minimum , maximum and average time between the first and second session for customers who do come back?2014 to date is good. 

--using the user_id to find any repeat sessions those users had 
with sessions_w_repeats as(                                
select 		 
new_session.user_id, 
new_session.session new_session_id, 
new_session.created_at new_session_date, 
w.website_session_id repeat_session_id, 
w.created_at repeat_session_date 
from( 
--subquery for finding new session /first session and date 
select	user_id, website_session_id session, created_at  
from 
website_sessions 
where  
created_at >= '2014-01-01' 
and created_at < '2014-11-03' 
and is_repeat_session=0 
) as new_session 
left join website_sessions as w				 
on  w.user_id=new_session.user_id 
and  is_repeat_session=1) 
--find difference between first and second sessions at a user level 
,users_first_to_second as(	 
select user_id, datediff(day,new_session_date,second_session_date) days 
From (
--finding the created_at times for first and second sessions 
select user_id, new_session_id, new_session_date, min(repeat_session_id) second_session_id, 
min(repeat_session_date) second_session_date  
from sessions_w_repeats 
where repeat_session_id is not null 
group by user_id, 
new_session_id, 
new_session_date) as first_second) 
--calculate avg min max for repeat customer  
select					 
avg(days) as avg_days_first_second_session, 
min(days) as min_days_first_second_session, 
max(days) as max_days_first_second_session 
from users_first_to_second; 

-------------------------------------------------------------------------------------------------------------------------
--Qn29. New vs. repeat channel patterns
--comparing new vs repeat sessions by channel

--repeat sessions
select count(user_id)as no_of_users,utm_source, utm_campaign
from
(select distinct o.user_id,
ws.utm_source,utm_campaign,
datepart(yyyy,o.created_at) as yearly, 
count(o.website_session_id) as no_of_sessions
from website_sessions ws
inner join orders o
on o.website_session_id=ws.website_session_id
where o.created_at>='2014-01-01 00:46:30.0000000'
group by o.user_id, datepart(yyyy,o.created_at),utm_source,utm_campaign
having count(o.website_session_id)>1
) as a
group by utm_source, utm_campaign
;

--new sessions
select count(user_id)as no_of_users,utm_source,utm_campaign
from
(select distinct o.user_id,
ws.utm_source,ws.utm_campaign,
datepart(yyyy,o.created_at) as yearly, 
count(o.website_session_id) as no_of_sessions
from website_sessions ws
inner join orders o
on o.website_session_id=ws.website_session_id
where o.created_at>='2014-01-01 00:46:30.0000000'
group by o.user_id, datepart(yyyy,o.created_at),utm_source,utm_campaign
having count(o.website_session_id)=1
) as a
group by utm_source,utm_campaign
;

------------------------------------------------------------------------------------------------------------------------------------------
--Q30.New Vs. Repeat Performance: Provide analysis on comparison of conversion rates and revenue per session for
--repeat sessions vs new sessions?2014 to date is good. 

select  
case when is_repeat_session =0 then 'New user' else 'Repeat user' end as users, 
count(distinct w.website_session_id) sessions, 
count(distinct o.order_id)*100.0/count(distinct w.website_session_id) conversion_rate, 
sum(price_usd)/count(distinct w.website_session_id) revenue_per_session 
from website_sessions w 
left join orders o 
on o.website_session_id=w.website_session_id 
where w.created_at >= '2014-01-01' 
and  w.created_at < '2014-11-08' 
group by case when is_repeat_session =0 then 'New user' else 'Repeat user' end ; 

 

 



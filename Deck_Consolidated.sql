
------------------------------------------------------DECK QUESTIONS-------------------------------------------------------------
--First, I’d like to show our volume growth. Can you pull overall session and order volume, trended by quarter for the life of the
--business? Since the most recent quarter is incomplete, you can decide how to handle it.
SELECT M.Year_,M.US_Quarter,M.Total_Sessions,L.Total_Orders 
FROM (SELECT TOP 12 DATEPART(YEAR,A.created_at) AS Year_,
                    DATEPART(QUARTER,A.created_at) AS US_Quarter,
					COUNT(*) AS Total_Sessions FROM website_sessions AS A
      GROUP BY DATEPART(YEAR,A.created_at),
	           DATEPART(QUARTER,A.created_at)
      ORDER BY DATEPART(YEAR,A.created_at) ASC,
	           DATEPART(QUARTER,A.created_at) ASC ) AS M
      Left Join 
     (SELECT TOP 12 DATEPART(YEAR,A.created_at) AS Year_,
                    DATEPART(QUARTER,A.created_at) AS US_Quarter,
					COUNT(*) AS Total_Orders FROM orders AS A
      GROUP BY DATEPART(YEAR,A.created_at),
	           DATEPART(QUARTER,A.created_at)
      ORDER BY DATEPART(YEAR,A.created_at) ASC,
	           DATEPART(QUARTER,A.created_at) ASC ) AS L
      ON M.Year_ = L.Year_ AND M.US_Quarter = L.US_Quarter

-- Next, let’s showcase all of our efficiency improvements. I would love to show quarterly figures since we launched,
-- for session-to order conversion rate, revenue per order, and revenue per session.
SELECT O.Year_,O.US_Quarter,
       ((O.Total_Orders*100.00)/O.Total_Sessions) AS Conversion_Rate,
       (O.revenue/O.Total_Orders) AS Revenue_Per_Order,
	   (O.revenue/O.Total_Sessions) AS Revenue_Per_Session
FROM (SELECT M.Year_,M.US_Quarter,
             M.Total_Sessions,L.Total_Orders,
			 L.revenue 
			 FROM (SELECT TOP 12 DATEPART(YEAR,A.created_at) AS Year_,
                                 DATEPART(QUARTER,A.created_at) AS US_Quarter,
								 COUNT(*) AS Total_Sessions FROM website_sessions AS A
                   GROUP BY DATEPART(YEAR,A.created_at),
				            DATEPART(QUARTER,A.created_at)
                   ORDER BY DATEPART(YEAR,A.created_at) ASC,
				            DATEPART(QUARTER,A.created_at) ASC ) AS M
                   Left Join 
                  (SELECT TOP 12 DATEPART(YEAR,A.created_at) AS Year_,
                                 DATEPART(QUARTER,A.created_at) AS US_Quarter,
								 COUNT(*) AS Total_Orders,
	                             SUM(A.price_usd) AS revenue FROM orders AS A
                   GROUP BY DATEPART(YEAR,A.created_at),
				            DATEPART(QUARTER,A.created_at)
                   ORDER BY DATEPART(YEAR,A.created_at) ASC,
				            DATEPART(QUARTER,A.created_at) ASC ) AS L
                   ON M.Year_ = L.Year_ AND M.US_Quarter = L.US_Quarter ) AS O

-- Gsearch seems to be the biggest driver of our business. Could you pull monthly trends for gsearch sessions and orders
-- so that we can showcase the growth there?
SELECT L.Year_,L.Month_,L.Orders,P.Sessions_ 
FROM (SELECT DATEPART(YEAR,A.created_at) AS Year_,
             DATEPART(MONTH,A.created_at) AS Month_,
             COUNT(*) AS Sessions_  FROM website_sessions AS A
      WHERE A.utm_source = 'gsearch'
      GROUP BY DATEPART(YEAR,A.created_at),
	           DATEPART(MONTH,A.created_at)) AS P
     LEFT JOIN
     (SELECT DATEPART(YEAR,B.created_at) AS Year_,
	         DATEPART(MONTH,B.created_at) AS Month_,
             COUNT(b.order_id) AS Orders FROM orders AS B
      WHERE B.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                                     WHERE A.utm_source = 'gsearch')
      GROUP BY DATEPART(YEAR,B.created_at),
	           DATEPART(MONTH,B.created_at)) AS L
      ON L.Month_ = P.Month_ AND L.Year_ = P.Year_
ORDER BY L.Year_ ASC , L.Month_ ASC

--Next, it would be great to see a similar monthly trend for Gsearch, but this time splitting out nonbrand and brand campaigns 
--separately. I am wondering if brand is picking up at all. If so, this is a good story to tell.

--For Non Brand
SELECT L.Year_,L.Month_,L.Orders,P.Sessions_ 
FROM (SELECT DATEPART(YEAR,A.created_at) AS Year_,
             DATEPART(MONTH,A.created_at) AS Month_,
             COUNT(*) AS Sessions_  FROM website_sessions AS A
      WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand'
      GROUP BY DATEPART(YEAR,A.created_at),
	           DATEPART(MONTH,A.created_at)) AS P
      LEFT JOIN
     (SELECT DATEPART(YEAR,B.created_at) AS Year_,
	         DATEPART(MONTH,B.created_at) AS Month_,
             COUNT(b.order_id) AS Orders FROM orders AS B
      WHERE B.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                                     WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand')
      GROUP BY DATEPART(YEAR,B.created_at),
	           DATEPART(MONTH,B.created_at)) AS L
ON L.Month_ = P.Month_ AND L.Year_ = P.Year_
ORDER BY L.Year_ ASC , L.Month_ ASC

--For Brand
SELECT P.Year_,P.Month_,L.Orders,P.Sessions_ 
FROM (SELECT DATEPART(YEAR,A.created_at) AS Year_,
             DATEPART(MONTH,A.created_at) AS Month_,
             COUNT(*) AS Sessions_  FROM website_sessions AS A
      WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'brand'
      GROUP BY DATEPART(YEAR,A.created_at),
	           DATEPART(MONTH,A.created_at)) AS P
      LEFT JOIN
     (SELECT DATEPART(YEAR,B.created_at) AS Year_,
	         DATEPART(MONTH,B.created_at) AS Month_,
             COUNT(b.order_id) AS Orders FROM orders AS B
      WHERE B.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                                     WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'brand')
      GROUP BY DATEPART(YEAR,B.created_at),
	           DATEPART(MONTH,B.created_at)) AS L
ON L.Month_ = P.Month_ AND L.Year_ = P.Year_
ORDER BY P.Year_ ASC , P.Month_ ASC

-- While we’re on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type? 
-- I want to flex our analytical muscles a little and show the board we really know our traffic sources.
SELECT D.Year_,D.Month_,
       D.Mobile_Sessions,U.Desktop_Sessions,
       D.Mobile_Orders,U.Desktop_Orders 
FROM (SELECT P.Year_,P.Month_,
             L.Orders AS Mobile_Orders,P.Sessions_ AS Mobile_Sessions 
	  FROM (SELECT DATEPART(YEAR,A.created_at) AS Year_,
	               DATEPART(MONTH,A.created_at) AS Month_,
                   COUNT(*) AS Sessions_  FROM website_sessions AS A
            WHERE A.utm_source = 'gsearch' AND 
			      A.utm_campaign = 'nonbrand' AND 
				  A.device_type = 'mobile'
            GROUP BY DATEPART(YEAR,A.created_at),
			         DATEPART(MONTH,A.created_at)) AS P
           LEFT JOIN
          (SELECT DATEPART(YEAR,B.created_at) AS Year_,
		          DATEPART(MONTH,B.created_at) AS Month_,
                  COUNT(b.order_id) AS Orders FROM orders AS B
           WHERE B.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                                           WHERE A.utm_source = 'gsearch' AND 
										         A.utm_campaign = 'nonbrand' AND 
												 A.device_type = 'mobile')            
		   GROUP BY DATEPART(YEAR,B.created_at),
		            DATEPART(MONTH,B.created_at)) AS L
           ON L.Month_ = P.Month_ AND L.Year_ = P.Year_) AS D
LEFT JOIN
(SELECT P.Year_,P.Month_,L.Orders AS Desktop_Orders,P.Sessions_ AS Desktop_Sessions FROM (
SELECT DATEPART(YEAR,A.created_at) AS Year_,DATEPART(MONTH,A.created_at) AS Month_,
       COUNT(*) AS Sessions_  FROM website_sessions AS A
WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand' AND A.device_type = 'desktop'
GROUP BY DATEPART(YEAR,A.created_at),DATEPART(MONTH,A.created_at)
) AS P
LEFT JOIN
(SELECT DATEPART(YEAR,B.created_at) AS Year_,DATEPART(MONTH,B.created_at) AS Month_,
       COUNT(b.order_id) AS Orders FROM orders AS B
WHERE B.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                                WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand' AND A.device_type = 'desktop')
GROUP BY DATEPART(YEAR,B.created_at),DATEPART(MONTH,B.created_at)
) AS L
ON L.Month_ = P.Month_ AND L.Year_ = P.Year_
) AS U
ON U.Month_ = D.Month_ AND U.Year_ = D.Year_
ORDER BY D.Year_ ASC , D.Month_ ASC 

-- I’m worried that one of our more pessimistic board members may be concerned about the large % 
-- of traffic from Gsearch. Can you pull monthly trends for Gsearch, alongside monthly trends for each of our other channels?
SELECT * INTO Channel_Trend FROM (
SELECT P.Year_,P.Month_,L.utm_source,L.Orders,P.Sessions_ FROM (
SELECT DATEPART(YEAR,A.created_at) AS Year_,DATEPART(MONTH,A.created_at) AS Month_,A.utm_source,
       COUNT(*) AS Sessions_  FROM website_sessions AS A
GROUP BY DATEPART(YEAR,A.created_at),DATEPART(MONTH,A.created_at),A.utm_source
) AS P
LEFT JOIN
(SELECT DATEPART(YEAR,B.created_at) AS Year_,DATEPART(MONTH,B.created_at) AS Month_,M.utm_source,
       COUNT(b.order_id) AS Orders FROM orders AS B
LEFT JOIN 
website_sessions AS M
ON M.website_session_id = B.website_session_id
GROUP BY DATEPART(YEAR,B.created_at),DATEPART(MONTH,B.created_at),M.utm_source
) AS L
ON L.Month_ = P.Month_ AND L.Year_ = P.Year_ AND L.utm_source = P.utm_source
 ) AS A

 SELECT * FROM Channel_Trend AS L

 --For Orders
 SELECT L.Year_,L.Month_,L.GSearch,M.BSearch,N.Socialbook,O.OrganicSearch,P.DirectTypin FROM (
 SELECT A.Year_,A.Month_,A.Orders AS GSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'gsearch') AS L
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Orders AS BSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'bsearch') AS M
 ON L.Year_ = M.Year_ AND L.Month_ = M.Month_
 LEFT JOIN
 (SELECT A.Year_,A.Month_,A.Orders AS Socialbook FROM Channel_Trend AS A
 WHERE A.utm_source = 'socialbook') AS N
 ON L.Year_ = N.Year_ AND L.Month_ = N.Month_
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Orders AS OrganicSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'organic_search') AS O
 ON L.Year_ = O.Year_ AND L.Month_ = O.Month_
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Orders AS DirectTypin FROM Channel_Trend AS A
WHERE A.utm_source = 'direct_typin') AS P
ON L.Year_ = P.Year_ AND L.Month_ = P.Month_
ORDER BY L.Year_,L.Month_

--For Sessions
SELECT L.Year_,L.Month_,L.GSearch,M.BSearch,N.Socialbook,O.OrganicSearch,P.DirectTypin FROM (
 SELECT A.Year_,A.Month_,A.Sessions_ AS GSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'gsearch') AS L
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sessions_ AS BSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'bsearch') AS M
 ON L.Year_ = M.Year_ AND L.Month_ = M.Month_
 LEFT JOIN
 (SELECT A.Year_,A.Month_,A.Sessions_ AS Socialbook FROM Channel_Trend AS A
 WHERE A.utm_source = 'socialbook') AS N
 ON L.Year_ = N.Year_ AND L.Month_ = N.Month_
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sessions_ AS OrganicSearch FROM Channel_Trend AS A
 WHERE A.utm_source = 'organic_search') AS O
 ON L.Year_ = O.Year_ AND L.Month_ = O.Month_
 LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sessions_ AS DirectTypin FROM Channel_Trend AS A
WHERE A.utm_source = 'direct_typin') AS P
ON L.Year_ = P.Year_ AND L.Month_ = P.Month_
ORDER BY L.Year_,L.Month_

-- I’d like to show how we’ve grown specific channels. Could you pull a quarterly view of orders from G search nonbrand,B search 
-- nonbrand, brand search overall, organic search, and direct type-in?
SELECT A.Year_,A.Quarter_,A.Orders_Gsearch,B.Orders_Bsearch,C.Orders_Brand,D.Orders_OrganicSearch,E.Orders_DirectTypin
FROM (
SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
	   COUNT(A.order_id) AS Orders_Gsearch FROM orders AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
WHERE B.utm_source = 'gsearch' AND B.utm_campaign = 'nonbrand'
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at) ) AS A
LEFT JOIN
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
	   COUNT(A.order_id) AS Orders_Bsearch FROM orders AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
WHERE B.utm_source = 'bsearch' AND B.utm_campaign = 'nonbrand'
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at) ) AS B
ON A.Year_ = B.Year_ AND A.Quarter_ = B.Quarter_
LEFT JOIN
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
	   COUNT(A.order_id) AS Orders_Brand FROM orders AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
WHERE B.utm_campaign = 'brand'
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at) ) AS C
ON A.Quarter_ = C.Quarter_ AND A.Year_ = C.Year_
LEFT JOIN 
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
	   COUNT(A.order_id) AS Orders_OrganicSearch FROM orders AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
WHERE B.utm_source = 'organic_search'
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at) ) AS D
ON A.Quarter_ = D.Quarter_ AND A.Year_ = D.Year_
LEFT JOIN
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
	   COUNT(A.order_id) AS Orders_DirectTypin FROM orders AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
WHERE B.utm_source = 'direct_typin'
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at) ) AS E
ON A.Quarter_ = E.Quarter_ AND A.Year_ = E.Year_
ORDER BY A.Year_ , A.Quarter_

-- Next, let’s show the overall session-to-order conversion rate trends for those same channels, by quarter. Please also 
-- make a note of any periods where we made major improvements or optimizations.
SELECT * INTO Improvement FROM 
(SELECT L.Year_,L.Quarter_,L.Channels,L.Sessions,D.Orders,
       (D.Orders*100.00)/(L.Sessions) AS Conversion_Rate FROM
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
       A.utm_source AS Channels,
       COUNT(DISTINCT A.website_session_id) AS Sessions FROM website_sessions AS A
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at),
         A.utm_source ) AS L
LEFT JOIN
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(QUARTER,A.created_at) AS Quarter_,
       B.utm_source AS Channels,
       COUNT(A.order_id) AS Orders FROM orders AS A
LEFT JOIN
       website_sessions AS B
	   ON A.website_session_id = B.website_session_id
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(QUARTER,A.created_at),
         B.utm_source ) AS D
 ON L.Quarter_ = D.Quarter_ AND L.Year_ = D.Year_ AND L.Channels = D.Channels
GROUP BY L.Year_,L.Quarter_,L.Channels,L.Sessions,D.Orders
) AS L

SELECT * FROM Improvement
--For Conversion Rate
SELECT L.Year_,L.Quarter_,L.GSearch,M.BSearch,N.Socialbook,O.OrganicSearch,P.DirectTypin FROM (
 SELECT A.Year_,A.Quarter_,A.Conversion_Rate AS GSearch FROM Improvement AS A
 WHERE A.Channels = 'gsearch') AS L
 LEFT JOIN
( SELECT A.Year_,A.Quarter_,A.Conversion_Rate AS BSearch FROM Improvement AS A
 WHERE A.Channels = 'bsearch') AS M
 ON L.Year_ = M.Year_ AND L.Quarter_ = M.Quarter_
 LEFT JOIN
 ( SELECT A.Year_,A.Quarter_,A.Conversion_Rate AS Socialbook FROM Improvement AS A
 WHERE A.Channels = 'socialbook') AS N
 ON L.Year_ = N.Year_ AND L.Quarter_ = N.Quarter_
 LEFT JOIN
( SELECT A.Year_,A.Quarter_,A.Conversion_Rate AS OrganicSearch FROM Improvement AS A
 WHERE A.Channels ='organic_search') AS O
 ON L.Year_ = O.Year_ AND L.Quarter_ = O.Quarter_
 LEFT JOIN
( SELECT A.Year_,A.Quarter_,A.Conversion_Rate AS DirectTypin FROM Improvement AS A
 WHERE A.Channels = 'direct_typin') AS P
ON L.Year_ = P.Year_ AND L.Quarter_ = P.Quarter_
ORDER BY L.Year_,L.Quarter_

-- We’ve come a long way since the days of selling a single product. Let’s pull monthly trending for revenue and 
-- margin by product,along with total sales and revenue. Note anything you notice about seasonality.
SELECT * INTO ProductDeatil From
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(MONTH,A.created_at) AS Month_,
	   B.product_name AS Product,
	   SUM(A.price_usd) AS Revenue,
	   COUNT(A.order_id) AS Sales,
	   SUM(A.price_usd - A.cogs_usd) AS Margin FROM orders AS A
LEFT JOIN
products AS B
ON B.product_id = A.primary_product_id
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(MONTH,A.created_at),
		 b.product_name
) AS M

SELECT * FROM ProductDeatil
--For Revenue
SELECT L.Year_,L.Month_,L.Mr_Fuzzy,M.Love_Bear,N.Birthday_Panda,O.Mini_Bear FROM (
SELECT A.Year_,A.Month_,A.Revenue AS Mr_Fuzzy From ProductDeatil AS A
WHERE A.Product = 'The Original Mr. Fuzzy') AS L
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Revenue AS Love_Bear From ProductDeatil AS A
WHERE A.Product = 'The Forever Love Bear') AS M
ON L.Month_ = M.Month_ AND L.Year_=M.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Revenue AS Birthday_Panda From ProductDeatil AS A
WHERE A.Product = 'The Birthday Sugar Panda') AS N
ON L.Month_ = N.Month_ AND L.Year_=N.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Revenue AS Mini_Bear From ProductDeatil AS A
WHERE A.Product = 'The Hudson River Mini Bear') AS O
ON L.Month_ = O.Month_ AND L.Year_=O.Year_
ORDER BY L.Year_,L.Month_

--For Sales
SELECT L.Year_,L.Month_,L.Mr_Fuzzy,M.Love_Bear,N.Birthday_Panda,O.Mini_Bear FROM (
SELECT A.Year_,A.Month_,A.Sales AS Mr_Fuzzy From ProductDeatil AS A
WHERE A.Product = 'The Original Mr. Fuzzy') AS L
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sales AS Love_Bear From ProductDeatil AS A
WHERE A.Product = 'The Forever Love Bear') AS M
ON L.Month_ = M.Month_ AND L.Year_=M.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sales AS Birthday_Panda From ProductDeatil AS A
WHERE A.Product = 'The Birthday Sugar Panda') AS N
ON L.Month_ = N.Month_ AND L.Year_=N.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Sales AS Mini_Bear From ProductDeatil AS A
WHERE A.Product = 'The Hudson River Mini Bear') AS O
ON L.Month_ = O.Month_ AND L.Year_=O.Year_
ORDER BY L.Year_,L.Month_

--For Margin
SELECT L.Year_,L.Month_,L.Mr_Fuzzy,M.Love_Bear,N.Birthday_Panda,O.Mini_Bear FROM (
SELECT A.Year_,A.Month_,A.Margin AS Mr_Fuzzy From ProductDeatil AS A
WHERE A.Product = 'The Original Mr. Fuzzy') AS L
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Margin AS Love_Bear From ProductDeatil AS A
WHERE A.Product = 'The Forever Love Bear') AS M
ON L.Month_ = M.Month_ AND L.Year_=M.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Margin AS Birthday_Panda From ProductDeatil AS A
WHERE A.Product = 'The Birthday Sugar Panda') AS N
ON L.Month_ = N.Month_ AND L.Year_=N.Year_
LEFT JOIN
(SELECT A.Year_,A.Month_,A.Margin AS Mini_Bear From ProductDeatil AS A
WHERE A.Product = 'The Hudson River Mini Bear') AS O
ON L.Month_ = O.Month_ AND L.Year_=O.Year_
ORDER BY L.Year_,L.Month_

-- Let’s dive deeper into the impact of introducing new products. Please pull monthly sessions to the /products page, and
-- show how the % of those sessions clicking through another page has changed over time, along with a view of how conversion
-- from /products to placing an order has improved.

--Click-through rate
SELECT *,(L.Product_Sessions*100.0/L.Sessions_) AS Click_Through_Rate FROM
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(MONTH,A.created_at) AS Month_,
	   COUNT(A.website_session_id) AS Sessions_,
	   SUM(CASE WHEN B.pageview_url = '/products' THEN 1 ELSE 0 END) AS Product_Sessions FROM website_sessions AS A
LEFT JOIN 
website_pageviews AS B
ON A.website_session_id = B.website_session_id
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(MONTH,A.created_at) ) AS L
ORDER BY L.Year_,L.Month_

--Conversion_Rate
SELECT M.Year_,M.Month_,M.Product_Sessions,L.Orders,
       (L.Orders*100.0/M.Product_Sessions) AS Conversion_Rate_For_Products  FROM 
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(MONTH,A.created_at) AS Month_,
	   SUM(CASE WHEN B.pageview_url = '/products' THEN 1 ELSE 0 END) AS Product_Sessions FROM website_sessions AS A
LEFT JOIN 
website_pageviews AS B
ON A.website_session_id = B.website_session_id
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(MONTH,A.created_at) ) AS M
LEFT JOIN
(SELECT DATEPART(YEAR,C.created_at) AS Year_,
       DATEPART(MONTH,C.created_at) AS Month_,
	   COUNT(C.order_id) AS Orders  FROM  orders AS C
WHERE C.website_session_id IN (SELECT A.website_session_id FROM website_sessions AS A
                               LEFT JOIN 
                               website_pageviews AS B
                               ON A.website_session_id = B.website_session_id
                               WHERE B.pageview_url = '/products')
GROUP BY DATEPART(YEAR,C.created_at),
         DATEPART(MONTH,C.created_at) ) AS L
ON M.Month_=L.Month_ AND M.Year_ = L.Year_
ORDER BY M.Year_,M.Month_

-- I’d like to tell the story of our website performance improvements over the course of the first 8 months. 
-- Could you pull session to order conversion rates, by month?
SELECT TOP 8 L.Year_,L.Month_,L.Orders_,P.Sessions_,
       (L.Orders_*100.0/P.Sessions_) AS Converion_Rate  FROM
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(MONTH,A.created_at) AS Month_,
	   COUNT(A.website_session_id) AS Sessions_ FROM website_sessions AS A
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(MONTH,A.created_at) ) AS P
LEFT JOIN
(SELECT DATEPART(YEAR,A.created_at) AS Year_,
       DATEPART(MONTH,A.created_at) AS Month_,
	   COUNT(A.order_id) AS Orders_ FROM orders AS A
GROUP BY DATEPART(YEAR,A.created_at),
         DATEPART(MONTH,A.created_at)) AS L
		 ON P.Month_ = L.Month_ AND P.Year_ = L.Year_
ORDER BY L.Year_,L.Month_

-- For the gsearch lander test, please estimate the revenue that test earned us (Hint: Look at the increase in CVR from 
-- the test (Jun 19 – Jul 28), and use nonbrand sessions and revenue since then to calculate incremental value)

--For (Jun 19 – Jul 28)
SELECT COUNT(A.website_session_id) AS After_Sessions,
       COUNT(B.order_id) AS After_Order,
	   SUM(B.price_usd) AS After_Revenue,
	   (COUNT(B.order_id)*100.0/COUNT(A.website_session_id)) AS After_Conversion_Rate FROM website_sessions AS A
LEFT JOIN 
         orders AS B
		 ON A.website_session_id = B.website_session_id
WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand' AND
     A.created_at > = '2012-06-19' AND A.created_at < = '2012-07-28'

--For (May 10 – Jun 18)
SELECT COUNT(A.website_session_id) AS Before_Sessions,
       COUNT(B.order_id) AS Before_Order,
	   SUM(B.price_usd) AS Before_Revenue,
	   (COUNT(B.order_id)*100.0/COUNT(A.website_session_id)) AS Before_Conversion_Rate FROM website_sessions AS A
LEFT JOIN 
         orders AS B
		 ON A.website_session_id = B.website_session_id
WHERE A.utm_source = 'gsearch' AND A.utm_campaign = 'nonbrand' AND
     A.created_at > = '2012-05-10' AND A.created_at < = '2012-06-18'

--Conclusion 
--Incremental CVR = 0.52
--Incremental Revenue = 1.64 K USD
--Incremental Orders = 33
--Incremental Sessions = 295

-- For the landing page test you analyzed previously, it would be great to show a full conversion funnel from each of 
-- the two pages to orders. You can use the same time period you analyzed last time (Jun 19 – Jul 28).

--Conversion Funnel
WITH flagged_sessions AS ( 

  SELECT 

    s.website_session_id, 

    MAX(CASE WHEN p.pageview_url = '/home' THEN 1 ELSE 0 END) AS saw_homepage, 

    MAX(CASE WHEN p.pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS saw_custom_lander, 

    MAX(CASE WHEN p.pageview_url = '/products' THEN 1 ELSE 0 END) AS product_made_it, 

    MAX(CASE WHEN p.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS mrfuzzy_page_made_it, 

    MAX(CASE WHEN p.pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart_page_made_it, 

    MAX(CASE WHEN p.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS shipping_page_made_it, 

    MAX(CASE WHEN p.pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing_page_made_it, 

    MAX(CASE WHEN p.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS thankyou_page_made_it 

  FROM website_sessions s 

  LEFT JOIN website_pageviews p 

    ON s.website_session_id = p.website_session_id 

  WHERE s.utm_source = 'gsearch' 

    AND s.utm_campaign = 'nonbrand' 

    AND s.created_at BETWEEN '2012-06-19' AND '2012-07-28' 

  GROUP BY s.website_session_id 

), 

  

--  Group sessions by landing page and calculate conversion funnel metrics 

conversion_funnel AS ( 

  SELECT 

    CASE  

      WHEN saw_homepage = 1 THEN 'saw_homepage' 

      WHEN saw_custom_lander = 1 THEN 'saw_custom_lander' 

      ELSE 'check logic'  

    END AS segment, 

    COUNT(DISTINCT website_session_id) AS sessions, 

    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products, 

    COUNT(DISTINCT CASE WHEN mrfuzzy_page_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy, 

    COUNT(DISTINCT CASE WHEN cart_page_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart, 

    COUNT(DISTINCT CASE WHEN shipping_page_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping, 

    COUNT(DISTINCT CASE WHEN billing_page_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing, 

    COUNT(DISTINCT CASE WHEN thankyou_page_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou 

  FROM flagged_sessions 

  GROUP BY  

    CASE  

      WHEN saw_homepage = 1 THEN 'saw_homepage' 

      WHEN saw_custom_lander = 1 THEN 'saw_custom_lander' 

      ELSE 'check logic'  

    END 

) 

--Calculate click-through rates 

SELECT 

  segment, 

  sessions, 

  ROUND(100.0 * to_products / sessions, 2) AS product_click_rt, 

  ROUND(100.0 * to_mrfuzzy / sessions, 2) AS mrfuzzy_click_rt, 

  ROUND(100.0 * to_cart / sessions, 2) AS cart_click_rt, 

  ROUND(100.0 * to_shipping / sessions, 2) AS shipping_click_rt, 

  ROUND(100.0 * to_billing / sessions, 2) AS billing_click_rt, 

  ROUND(100.0 * to_thankyou / sessions, 2) AS thankyou_click_rt 

FROM conversion_funnel; 


--I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated from the test 
--(Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number of billing page sessions 
--for the past month to understand monthly impact.

SELECT O.pageview_url,D.Before_Sessions,D.Before_Revenue,
       D.Before_revenue_per_billing_session,O.After_Sessions,O.After_Revenue,
	   O.After_revenue_per_billing_session FROM (
--For (Sep 10 – Nov 10)
SELECT A.pageview_url,
       COUNT(B.website_session_id) AS After_Sessions,
	   SUM(C.price_usd) AS After_Revenue,
	   (SUM(C.price_usd)/COUNT(B.website_session_id)) AS After_revenue_per_billing_session FROM website_pageviews AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
LEFT JOIN 
orders AS C
ON A.website_session_id = C.website_session_id
WHERE A.created_at >= '2012-09-10' AND A.created_at <= '2012-11-10' 
      AND A.pageview_url IN ('/billing-2','/billing')
GROUP BY A.pageview_url ) AS O
LEFT JOIN
(--For (Jul 10 – Sep 9)
SELECT A.pageview_url,
       COUNT(B.website_session_id) AS Before_Sessions,
	   SUM(C.price_usd) AS Before_Revenue,
	   (SUM(C.price_usd)/COUNT(B.website_session_id)) AS Before_revenue_per_billing_session FROM website_pageviews AS A
LEFT JOIN 
website_sessions AS B
ON A.website_session_id = B.website_session_id
LEFT JOIN 
orders AS C
ON A.website_session_id = C.website_session_id
WHERE A.created_at >= '2012-07-10' AND A.created_at <= '2012-09-10' 
      AND A.pageview_url IN ('/billing-2','/billing')
GROUP BY A.pageview_url ) AS D
ON D.pageview_url = O.pageview_url

-- We made our 4th product available as a primary product on December 05, 2014 (it was previously only a cross-sell item). Could you 
-- please pull sales data since then, and show how well each product cross-sells from one another?

--CrossSellPerformance
SELECT A.product_id AS PrimaryProduct,
       B.product_id AS CrossSellProduct,
       COUNT(DISTINCT A.order_id) AS CrossSellCount
FROM (SELECT order_id,product_id,is_primary_item,created_at FROM order_items
      WHERE created_at >= '2014-12-05') AS A
JOIN
     (SELECT order_id,product_id,is_primary_item,created_at FROM order_items
      WHERE created_at >= '2014-12-05') AS B
ON A.order_id = B.order_id
   AND A.product_id <> B.product_id
   AND A.is_primary_item = 1
   AND B.is_primary_item = 0
GROUP BY A.product_id,B.product_id
ORDER BY A.product_id

---View of the entire table
SELECT *
FROM [ChicagoTaxi Trips].[dbo].[Data$]

---Set Trip timestamp columns in a more proper data type 
UPDATE [ChicagoTaxi Trips].[dbo].[Data$]
set [Trip Start Timestamp]=cast((CONVERT(datetime, [Trip Start Timestamp],102)) as datetime)

UPDATE [ChicagoTaxi Trips].[dbo].[Data$]
set [Trip End Timestamp]=cast((CONVERT(datetime, [Trip End Timestamp],102)) as datetime)

---Number of Taxi Trip for each month (month number)
SELECT MONTH([Trip Start Timestamp]) AS TripMonth, COUNT(*) AS NumberOfTrips
FROM [ChicagoTaxi Trips].[dbo].[Data$]
GROUP BY MONTH([Trip Start Timestamp])
ORDER BY NumberOfTrips DESC

---Number of Taxi Trip for each month (month name)
SELECT DATENAME(MONTH, [Trip Start Timestamp]) AS TripMonth, COUNT(*) AS NumberOfTrips
FROM [ChicagoTaxi Trips].[dbo].[Data$]
GROUP BY DATENAME(MONTH, [Trip Start Timestamp])
ORDER BY NumberOfTrips DESC

---Most common Payment Type
SELECT [Payment Type], count(*) as NumberOfPayment
FROM [ChicagoTaxi Trips].[dbo].[Data$]
GROUP BY [Payment Type]
ORDER BY count(*) DESC

---Average Trip time (in minutes) and lenght
select AVG(CAST(REPLACE([Trip Seconds],',','') as float))/60 as AvgTripTime, AVG([Trip Miles]) as AvgTripLenght
FROM [ChicagoTaxi Trips].[dbo].[Data$]

---Taxi demand prediction: calculation of the rolling average number for each day over a period between the preceding 5 days and the following 5 days to see.
---The purpose is to eliminate the random component of the day and take the mean based on the period
with daily_trips as (
SELECT CAST([Trip Start Timestamp] as date) as TripDay, count(*) as TripsNumber
FROM [ChicagoTaxi Trips].[dbo].[Data$]
GROUP BY CAST([Trip Start Timestamp] as date)
) 
SELECT TripDay, AVG(TripsNumber) over (ORDER BY TripDay ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) AS AvgTripNumber
FROM daily_trips

---For each community area return the number of each trip around the year
	---Usign the rank funtion (trips with the same timestamp have the same trip number)
SELECT [Trip ID],[Taxi ID],[Pickup Community Area], 
[Trip Start Timestamp],
[Trip End Timestamp], RANK()
OVER(PARTITION BY [Pickup Community Area] 
ORDER BY [Trip Start Timestamp]) AS TripNumber
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Pickup Community Area] IS NOT NULL


	---Usign the row number funtion (trips with the same timestamp have the consecutive trip number)
SELECT [Trip ID],[Taxi ID],[Pickup Community Area], 
[Trip Start Timestamp],
[Trip End Timestamp], ROW_NUMBER()
OVER(PARTITION BY [Pickup Community Area] 
ORDER BY [Trip Start Timestamp]) AS TripNumber
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Pickup Community Area] IS NOT NULL


---Time elapsed between two different trips for the same taxi driver in minutes
	---Method 1 (The difference between the first trip of a day and the last trip of the previuos work day is null)
	
SELECT [Trip ID],[Taxi ID], [Trip Start Timestamp], [Trip End Timestamp], 
DATEDIFF(minute, [Trip Start Timestamp], lag([Trip End Timestamp]) OVER (PARTITION BY [Taxi ID], cast ([Trip Start Timestamp] as DATE)  ORDER BY cast([Trip Start Timestamp] as DATETIME)))*-1 as BreakTime
FROM [ChicagoTaxi Trips].[dbo].[Data$] 
WHERE [Taxi ID] IS NOT NULL AND DATEDIFF(minute, [Trip Start Timestamp], [Trip End Timestamp])>0

	---Method 2 (Calculate also the difference between the first trip of a day and the last trip of the previuos work day)
SELECT [Trip ID],[Taxi ID], [Trip Start Timestamp], [Trip End Timestamp], 
DATEDIFF(minute, lag([Trip End Timestamp]) OVER (PARTITION BY [Taxi ID] ORDER BY cast([Trip Start Timestamp] as DATETIME)), [Trip Start Timestamp]) as BreakTime
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Taxi ID] IS NOT NULL AND DATEDIFF(minute, [Trip Start Timestamp], [Trip End Timestamp])>0


---Cumulative Trip Miles for each taxi
Select [Trip ID],[Taxi ID] , [Trip Miles], [Trip Start Timestamp],
SUM([Trip Miles]) 
OVER (PARTITION BY [Taxi ID] order by cast([Trip Start Timestamp] as datetime) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningMiles
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Taxi ID] IS NOT NULL

---Daily cumulative Trip Miles for each taxi
Select [Trip ID],[Taxi ID] , [Trip Miles], [Trip Start Timestamp], [Trip End Timestamp],
SUM([Trip Miles]) 
OVER (PARTITION BY [Taxi ID], cast([Trip Start Timestamp] as date) order by cast([Trip Start Timestamp] as datetime) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningMiles
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Taxi ID] IS NOT NULL

---Monthly cumulative Trip Miles for each taxi
Select [Trip ID],[Taxi ID] , [Trip Miles], [Trip Start Timestamp], [Trip End Timestamp],
SUM([Trip Miles]) 
OVER (PARTITION BY [Taxi ID], MONTH(cast([Trip Start Timestamp] as date)) order by cast([Trip Start Timestamp] as datetime) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningMiles
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Taxi ID] IS NOT NULL

---Cumulative number of trips for each taxi, each day
with DailyTrips as(
SELECT [Taxi ID], CAST([Trip Start Timestamp] AS DATE) AS TripDay, count(*) as NumberOfTrips
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Trip Miles]>0
GROUP BY [Taxi ID], CAST([Trip Start Timestamp] AS DATE)
)select [Taxi ID], TripDay, sum(NumberOfTrips) OVER (PARTITION BY [Taxi ID] ORDER BY TripDay ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as CumulativeTrips
from DailyTrips

---First Pickup and Last Dropoff community Area for each taxi each day
SELECT [Trip ID],[Taxi ID], CAST([Trip Start Timestamp] AS DATE) AS TripDay, [Pickup Community Area],
FIRST_VALUE([Pickup Community Area]) OVER (PARTITION BY [Taxi ID], CAST([Trip Start Timestamp] AS DATE) ORDER BY [Trip Start Timestamp]) AS FirstPickUp,
[Dropoff Community Area],
LAST_VALUE([Dropoff Community Area]) 
OVER (PARTITION BY [Taxi ID], CAST([Trip Start Timestamp] AS DATE) ORDER BY [Trip Start Timestamp] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastDropOff
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Taxi ID] IS NOT NULL

---Taxi with the most number of miles done
WITH Miles_Done as (
SELECT [Taxi ID], sum([Trip Miles]) as MilesDone
FROM [ChicagoTaxi Trips].[dbo].[Data$]
GROUP BY [Taxi ID])
SELECT [Taxi ID], MilesDone
FROM Miles_Done
WHERE MilesDone=(select MAX(MilesDone) FROM Miles_Done)

---Taxi with the most number of trips done for each month
WITH Miles_Done2 as (
SELECT MONTH([Trip Start Timestamp]) AS TripMonth, [Taxi ID], sum([Trip Miles]) as MilesDone
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Trip Miles]>0
GROUP BY MONTH([Trip Start Timestamp]),[Taxi ID]
)
SELECT DISTINCT TripMonth, FIRST_VALUE([Taxi ID]) OVER (PARTITION BY TripMonth ORDER BY MilesDone DESC) as TaxiID, MAX(MilesDone) OVER (PARTITION BY TripMonth ORDER BY MilesDone DESC) as Miles
FROM Miles_Done2

---Taxi with the most number of trip done
WITH Trips_Done as (
SELECT [Taxi ID], count(*) as TripsDone
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Trip Miles]>0
GROUP BY [Taxi ID])
SELECT [Taxi ID], TripsDone
FROM Trips_Done
WHERE TripsDone=(select MAX(TripsDone) FROM Trips_Done)

---Taxi with the most number of trips done for each month
WITH Trips_Done2 as (
SELECT MONTH([Trip Start Timestamp]) AS TripMonth, [Taxi ID], count(*) as TripsDone
FROM [ChicagoTaxi Trips].[dbo].[Data$]
WHERE [Trip Miles]>0
GROUP BY MONTH([Trip Start Timestamp]),[Taxi ID]
)
SELECT DISTINCT TripMonth, FIRST_VALUE([Taxi ID]) OVER (PARTITION BY TripMonth ORDER BY TripsDone DESC) as TaxiID, MAX(TripsDone) OVER (PARTITION BY TripMonth ORDER BY TripsDone DESC) as TripNumber
FROM Trips_Done2











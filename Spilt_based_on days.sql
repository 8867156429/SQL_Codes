-- 2)
-- Data Warehouse Queries
  
create table warehouse
                  (
                  ID varchar(10),
                  OnHandQuantity int,
                  OnHandQuantityDelta int,
                  event_type varchar(10),
                  event_datetime timestamp
                  );

insert into warehouse values
            ('SH0013', 278, 99 , 'OutBound', '2020-05-25 0:25'),
            ('SH0012', 377, 31 , 'InBound', '2020-05-24 22:00'),
            ('SH0011', 346, 1 , 'OutBound', '2020-05-24 15:01'),
            ('SH0010', 346, 1 , 'OutBound', '2020-05-23 5:00'),
            ('SH009', 348, 102, 'InBound', '2020-04-25 18:00'),
            ('SH008', 246, 43 , 'InBound', '2020-04-25 2:00'),
            ('SH007', 203, 2 , 'OutBound', '2020-02-25 9:00'),
            ('SH006', 205, 129, 'OutBound', '2020-02-18 7:00'),
            ('SH005', 334, 1 , 'OutBound', '2020-02-18 8:00'),
            ('SH004', 335, 27 , 'OutBound', '2020-01-29 5:00'),
            ('SH003', 362, 120, 'InBound', '2019-12-31 2:00');
            
-- truncate table warehouse;
  
select * from warehouse;

  -- Sort the 0-90 days old and 91-180 days old stock in a year(Quarter vise)


with 
    wh as -- This CTE we make sure the latest stock should be above
        (select * from warehouse order by event_datetime desc),
    days as  -- This CTE we seperate the latest day with days req
        (select onhandquantity, event_datetime,
                (event_datetime - interval '90 DAY') as day90,
                (event_datetime - interval '180 DAY') as day180,
                (event_datetime - interval '270 DAY') as day270,
                (event_datetime - interval '365 DAY') as day365
        from wh limit 1),

-- First CTE that 0-90
    inv_90_days as
        (select sum(OnHandQuantityDelta) as DaysOld_90
            from wh 
         --If we use cross join wtevr data in table 1 and 2 will be join so no need of on statement
         -- Since only 1 record is their in days cte 
         cross join days d  
              where event_type = 'InBound'  
         -- Below will show only 0-90 days data
              and wh.event_datetime >= d.day90),
    -- The below CTE to make sure final inbound sum is less then available onhandquantity
    inv_90_days_final as 
        (select case when DaysOld_90 > d.onhandquantity then d.onhandquantity 
                           else DaysOld_90
                end DaysOld_90
        from inv_90_days
        cross join days d
        ),

-- Second CTE that 91-180  
   inv_180_days as
        (select sum(OnHandQuantityDelta) as DaysOld_180
            from wh 
         cross join days d  
              where event_type = 'InBound'
         -- for 91 -180 days we should not consider the first 90 days stock
         -- hence we use between 
              and wh.event_datetime between d.day180 and d.day90),
    --In below CTE for 91 -180 days we should not consider the first 90 days stock
    -- hence we sepract DaysOld_90 
    inv_180_days_final as  
        (select case when DaysOld_180 > (d.onhandquantity - DaysOld_90) then (d.onhandquantity - DaysOld_90) 
                           else DaysOld_180
                end DaysOld_180
        from inv_180_days
        cross join days d     -- we are using 3 tables here hence cross join two times
        cross join inv_90_days
        ),

-- Second CTE that 181-270
    inv_270_days as -- coalesce: if sum is null show it as zero
        (select coalesce(sum(OnHandQuantityDelta),0) as DaysOld_270
            from wh 
         cross join days d  
              where event_type = 'InBound'
              and wh.event_datetime between d.day270 and d.day180),

    inv_270_days_final as  
        (select case when DaysOld_270 > (d.onhandquantity -(DaysOld_90 + DaysOld_180)) 
                        then (d.onhandquantity - (DaysOld_90 + DaysOld_180)) 
                           else DaysOld_270
                end DaysOld_270
        from inv_270_days
        cross join days d
        cross join inv_90_days_final
        cross join inv_180_days_final
        ),
    

-- Second CTE that 270-365    
    inv_365_days as 
    (select coalesce(sum(OnHandQuantityDelta),0) as DaysOld_365
            from wh 
         cross join days d  
              where event_type = 'InBound'
              and wh.event_datetime between d.day365 and d.day270),

    inv_365_days_final as  
        (select case when DaysOld_365 > (d.onhandquantity -(DaysOld_90 + DaysOld_180 + DaysOld_270)) 
                        then (d.onhandquantity - (DaysOld_90 + DaysOld_180 + DaysOld_270)) 
                           else DaysOld_365
                end DaysOld_365
        from inv_365_days
        cross join days d
        cross join inv_90_days_final
        cross join inv_180_days_final
        cross join inv_270_days_final )



select DaysOld_90 as "0-90 days old",
       DaysOld_180 as "91-180 days old",
       DaysOld_270 as "181-270 days old",
       DaysOld_365 as "271-365 days old"
from inv_90_days_final
cross join inv_180_days_final
cross join inv_270_days_final
cross join inv_365_days_final;
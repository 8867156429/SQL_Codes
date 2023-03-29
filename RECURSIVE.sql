-- 1)
create database SQL_Q ;
                                
create or replace table orders              
( order_id varchar,
  quantity integer );
  
insert into orders values('o1', 3);
insert into orders values('o2', 2);
-- insert into orders values('o3', 2);

select * from orders;

-- RECURSIVE: To Split Tables based on the Quantity

with RECURSIVE order_split as                       
(
select order_id, 1 as quantity from orders
  union all
  select o.order_id, (o_s.quantity+1)
  from order_split o_s
  join orders o on o.order_id = o_s.order_id and 
                   o.quantity > o_s.quantity 
  )
  select order_id, 1 as quantity from order_split
  order by 1;

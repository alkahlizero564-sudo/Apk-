-- Behaviour of Alpha's "store" preset on a Supabase stand-in: run after the store SQL with prefix demo_store.
-- Fails (raises) on the first wrong permission.
\set ON_ERROR_STOP 1
delete from auth.users;
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'a@example.com', '{"full_name":"Ahmed"}'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.com', '{}'),
  ('33333333-3333-3333-3333-333333333333', 'owner@example.com', '{}');

do $$ begin
  if (select role from public.demo_store_profiles where email = 'owner@example.com') <> 'admin' then raise exception 'owner is not admin'; end if;
  if (select full_name from public.demo_store_profiles where email = 'a@example.com') <> 'Ahmed' then raise exception 'name not saved'; end if;
end $$;

-- customer A places an order and tries to set the admin-only status
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.demo_store_orders (items, phone, status) values ('2 bread', '0912345678', 'تم التسليم');
do $$ begin
  if (select status from public.demo_store_orders limit 1) <> 'جديد' then raise exception 'customer set an admin-only column'; end if;
  if (select count(*) from public.demo_store_notifications where to_role = 'admin') <> 1 then raise exception 'admin not notified of new order'; end if;
end $$;
-- customer A cannot add products (catalog)
do $$ begin
  begin
    insert into public.demo_store_products (title, price) values ('x', 1);
    raise exception 'customer added a product';
  exception when insufficient_privilege then null;
  end;
end $$;
-- customer A cannot make himself admin
do $$ begin
  begin
    update public.demo_store_profiles set role = 'admin' where id = auth.uid();
    raise exception 'customer became admin';
  exception when raise_exception then
    if sqlerrm <> 'only an admin can change roles' then raise; end if;
  end;
end $$;

-- customer B sees nothing of A
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$ begin
  if (select count(*) from public.demo_store_orders) <> 0 then raise exception 'B sees the orders of A'; end if;
  update public.demo_store_orders set items = 'hacked';
  delete from public.demo_store_orders;
end $$;

-- the admin sees and updates the order: A gets a notification
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$ begin
  if (select count(*) from public.demo_store_orders) <> 1 then raise exception 'admin does not see the order (or B changed it)'; end if;
  if (select items from public.demo_store_orders) <> '2 bread' then raise exception 'B changed the order of A'; end if;
  update public.demo_store_orders set status = 'في الطريق';
  insert into public.demo_store_products (title, price) values ('خبز', 2.5);
  if (select (public.demo_store_stats()->>'orders')::int) <> 1 then raise exception 'stats wrong'; end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$ begin
  if (select count(*) from public.demo_store_notifications where to_user = auth.uid()) <> 1 then raise exception 'A not notified of the status change'; end if;
  if (select count(*) from public.demo_store_products) <> 1 then raise exception 'customer cannot read the catalog'; end if;
  if (select count(*) from public.demo_store_notifications where to_role = 'customer') <> 1 then raise exception 'customers not told about the new product'; end if;
  begin
    perform public.demo_store_stats();
    raise exception 'customer read the stats';
  exception when raise_exception then
    if sqlerrm <> 'admins only' then raise; end if;
  end;
  perform public.demo_store_register_device('tok-1', 'customer', 'android');
end $$;
reset role;
select 'RLS test passed' as result;

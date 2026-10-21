-- Synthetic-only development seed for the Depo Tangerang Utara pilot.
-- Do not replace this with real outlet/customer data. Apply migrations first.
insert into public.territories (id, name, kind, parent_id) values
 ('10000000-0000-4000-8000-000000000001', 'Banten (contoh)', 'region', null),
 ('10000000-0000-4000-8000-000000000002', 'Depo Tangerang Utara (pilot demo)', 'depot', '10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000003', 'Kecamatan Contoh Utara', 'kecamatan', '10000000-0000-4000-8000-000000000002'),
 ('10000000-0000-4000-8000-000000000004', 'Kelurahan Contoh 01', 'kelurahan', '10000000-0000-4000-8000-000000000003')
on conflict (id) do nothing;

insert into public.channels (id, name) values
 ('20000000-0000-4000-8000-000000000001', 'Minimarket'),
 ('20000000-0000-4000-8000-000000000002', 'Grocery')
on conflict (id) do nothing;

insert into public.categories (id, name) values
 ('30000000-0000-4000-8000-000000000001', 'Biskuit'),
 ('30000000-0000-4000-8000-000000000002', 'Snack')
on conflict (id) do nothing;

insert into public.brands (id, name, owner_name, brand_type) values
 ('40000000-0000-4000-8000-000000000001', 'Merek Garudafood Contoh', 'Garudafood', 'garudafood'),
 ('40000000-0000-4000-8000-000000000002', 'Merek Kompetitor Contoh', 'Produsen Contoh', 'competitor')
on conflict (id) do nothing;

insert into public.units (id, code, name) values
 ('70000000-0000-4000-8000-000000000001', 'g', 'gram'),
 ('70000000-0000-4000-8000-000000000002', 'pcs', 'pieces')
on conflict (id) do nothing;

insert into public.products (id, sku_code, name, brand_id, category_id, package_size, pack_quantity, unit_id) values
 ('50000000-0000-4000-8000-000000000001', 'DEMO-TU-GF-001', 'Biskuit Garudafood Contoh', '40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', '100 g', 100, '70000000-0000-4000-8000-000000000001'),
 ('50000000-0000-4000-8000-000000000002', 'DEMO-TU-COMP-001', 'Biskuit Kompetitor Contoh', '40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', '90 g', 90, '70000000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.outlets (id, code, name, territory_id, channel_id, address) values
 ('60000000-0000-4000-8000-000000000001', 'DEMO-TU-OUTLET-001', 'Outlet Fiktif 001', '10000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', 'Alamat sintetis untuk pengembangan')
on conflict (id) do nothing;


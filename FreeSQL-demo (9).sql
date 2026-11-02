BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE rd_meals ADD (stock_qty NUMBER)';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-1430, -955) THEN RAISE; END IF;
END;
/

-- 2) الوجبات كما في شاشة إدارة الوجبات (الأسماء القديمة تبقى كما هي)
INSERT INTO rd_meals (meal_name, price)
SELECT 'وجبة غداء', 25 FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM rd_meals WHERE meal_name = 'وجبة غداء');
INSERT INTO rd_meals (meal_name, price)
SELECT 'باقة إفطار صائم معتمر', 14 FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM rd_meals WHERE meal_name = 'باقة إفطار صائم معتمر');

-- المخزون المتاح: يُملأ فقط لو العمود فاضي (لا يغيّر شيئاً موجوداً)
UPDATE rd_meals SET stock_qty = 350 WHERE meal_name = 'وجبة غداء'            AND stock_qty IS NULL;
UPDATE rd_meals SET stock_qty = 520 WHERE meal_name = 'باقة إفطار صائم معتمر' AND stock_qty IS NULL;
UPDATE rd_meals SET stock_qty = 210 WHERE meal_name = 'وجبة خفيفة للطريق'     AND stock_qty IS NULL;

-- 3) خدمتان ناقصتان في بطاقة «محطة حافلات مكة»
INSERT INTO rd_services (service_name)
SELECT 'عيادة طبية' FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_services WHERE service_name = 'عيادة طبية');
INSERT INTO rd_services (service_name)
SELECT 'تسهيلات حركة' FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_services WHERE service_name = 'تسهيلات حركة');

INSERT INTO rd_rest_stop_services (rest_stop_id, service_id)
SELECT st.rest_stop_id, sv.service_id
  FROM rd_rest_stops st, rd_services sv
 WHERE st.name = 'محطة حافلات مكة' AND sv.service_name IN ('عيادة طبية', 'تسهيلات حركة')
   AND NOT EXISTS (SELECT 1 FROM rd_rest_stop_services x
                    WHERE x.rest_stop_id = st.rest_stop_id AND x.service_id = sv.service_id);

-- 4) الحسابات الجديدة
-- 4.1 الكابتن تركي (صاحب حملة أنوار المشاعر) — 1,850 نقطة ومحفظة 1,450 ر.س
INSERT INTO rd_users (full_name, email, password, user_type, rating, trips_count, stations_count, loyalty_points, wallet_balance)
SELECT 'حملة أنوار المشاعر لخدمات المعتمرين وحجاج بيت الله', 'campaign@anwar.sa',
       LOWER(RAWTOHEX(STANDARD_HASH('1234','SHA256'))), 'CAMPAIGN', 4.9, 14, 6, 1850, 1450
  FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_users WHERE email = 'campaign@anwar.sa');

INSERT INTO rd_campaign_profiles (user_id, manager_name, license_no)
SELECT u.user_id, 'الكابتن تركي بن عبدالله العتيبي', '489201'
  FROM rd_users u WHERE u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_campaign_profiles p WHERE p.user_id = u.user_id);

-- 4.2 حملة الوفادة الكبرى (صاحبة طلب الوجبات #ORD-8821)
INSERT INTO rd_users (full_name, email, password, user_type, wallet_balance)
SELECT 'حملة الوفادة الكبرى لحجاج بيت الله', 'campaign@alwifada.sa',
       LOWER(RAWTOHEX(STANDARD_HASH('1234','SHA256'))), 'CAMPAIGN', 0
  FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_users WHERE email = 'campaign@alwifada.sa');

INSERT INTO rd_campaign_profiles (user_id, manager_name)
SELECT u.user_id, 'حملة الوفادة الكبرى'
  FROM rd_users u WHERE u.email = 'campaign@alwifada.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_campaign_profiles p WHERE p.user_id = u.user_id);

-- 4.3 مالك محطة واحة النخيل (أ/ تركي العتيبي) — اشتراك سنوي ساري 240 يوم، رصيد 48,250، أرباح 64,940
INSERT INTO rd_users (full_name, email, password, phone, user_type, subscription_status, subscription_expires_at, wallet_balance, total_earnings, stations_count)
SELECT 'تركي العتيبي', 'owner@nakheel.sa',
       LOWER(RAWTOHEX(STANDARD_HASH('1234','SHA256'))), NULL, 'OWNER', 'ACTIVE', TRUNC(SYSDATE) + 240, 48250, 64940, 1
  FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_users WHERE email = 'owner@nakheel.sa');

-- 5) المحطات الجديدة
-- 5.1 محطة واحة النخيل (من نموذج «إضافة محطة»)
INSERT INTO rd_rest_stops (owner_id, name, app_title, city, highway_name, address_label, description,
                           bus_capacity, waiting_capacity, open_time, status, plan_code, billing_cycle)
SELECT u.user_id, 'محطة واحة النخيل', 'محطة واحة النخيل', 'المدينة المنورة', 'طريق الهجرة السريع',
       'طريق الهجرة باتجاه مكة المكرمة', 'استراحة نموذجية لخدمة ضيوف الرحمن',
       30, 1500, '24/7', 'APPROVED', 'basic', 'YEARLY'
  FROM rd_users u
 WHERE u.email = 'owner@nakheel.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_rest_stops WHERE name = 'محطة واحة النخيل');

INSERT INTO rd_rest_stop_services (rest_stop_id, service_id)
SELECT st.rest_stop_id, sv.service_id
  FROM rd_rest_stops st, rd_services sv
 WHERE st.name = 'محطة واحة النخيل'
   AND sv.service_name IN ('وقود','صيانة حافلات','استراحة','مواقف','مصلى','دورات مياه','مطعم','متاجر','صراف آلي','واي فاي')
   AND NOT EXISTS (SELECT 1 FROM rd_rest_stop_services x
                    WHERE x.rest_stop_id = st.rest_stop_id AND x.service_id = sv.service_id);

-- 5.2 محطة جبل عمر (موجودة في حجز #RD-1004 فقط، بدون بقية تفاصيلها)
INSERT INTO rd_rest_stops (owner_id, name, app_title, city, plan_code, billing_cycle)
SELECT NULL, 'محطة جبل عمر', 'محطة جبل عمر', 'مكة المكرمة', 'basic', 'MONTHLY'
  FROM dual WHERE NOT EXISTS (SELECT 1 FROM rd_rest_stops WHERE name = 'محطة جبل عمر');

-- 6) تقييم عبدالله القرشي على «محطة قطار الحرمين» (شاشة تفاصيل المحطة)
INSERT INTO rd_reviews (rest_stop_id, reviewer_name, rating, comment_text)
SELECT st.rest_stop_id, 'عبدالله القرشي', 5,
       'نظافة المصليات ودورات المياه مبهرة للغاية، ووجود عمال تنظيم المواقف اختصر علينا أكثر من نصف ساعة أثناء النزول وتوزيع وجبات الحجاج.'
  FROM rd_rest_stops st
 WHERE st.app_title = 'محطة قطار الحرمين'
   AND NOT EXISTS (SELECT 1 FROM rd_reviews r
                    WHERE r.rest_stop_id = st.rest_stop_id AND r.reviewer_name = 'عبدالله القرشي');

-- 7) الحجوزات (شاشة «حجوزاتي»)
-- 7.1 الحجز النشط #RD-9924 — محطة جبل الكعبة، 17 سبتمبر 2026، رصيف B-12، 50 وجبة، مجاناً (مبادرة راحة ضيف)
INSERT INTO rd_bookings (rest_stop_id, driver_id, booking_date, arrival_time, expected_arrival, bus_count, people_count,
                         status, booking_code, bus_stop_bay, qr_code_token, total_amount, platform_fee, net_owner_amount, notes)
SELECT st.rest_stop_id, u.user_id, DATE '2026-09-17', '04:30 م', TIMESTAMP '2026-09-17 16:30:00', 2, 95,
       'confirmed', 'RD-9924', 'B-12', 'RD-9924-QR', 0, 0, 0, 'وقت التوقف 30 دقيقة • 50 وجبة مجهزة'
  FROM rd_rest_stops st, rd_users u
 WHERE st.name = 'محطة جبل الكعبة' AND u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_bookings x WHERE x.booking_code = 'RD-9924');

-- 7.2 الحجز القادم #RD-1004 — محطة جبل عمر، غداً 08:00 ص
INSERT INTO rd_bookings (rest_stop_id, driver_id, booking_date, arrival_time, expected_arrival, bus_count, people_count,
                         status, booking_code, qr_code_token, total_amount, platform_fee, net_owner_amount, notes)
SELECT st.rest_stop_id, u.user_id, DATE '2026-09-18', '08:00 ص', TIMESTAMP '2026-09-18 08:00:00', 1, 1,
       'confirmed', 'RD-1004', 'RD-1004-QR', 0, 0, 0, 'الخدمات: موقف ديزل سريع + مصلى الفجر + 50 قهوة وضيافة (مجدولة تلقائياً)'
  FROM rd_rest_stops st, rd_users u
 WHERE st.name = 'محطة جبل عمر' AND u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_bookings x WHERE x.booking_code = 'RD-1004');

-- 7.3 الحجوزات المكتملة السابقة
INSERT INTO rd_bookings (rest_stop_id, driver_id, booking_date, arrival_time, bus_count, people_count, status, booking_code, qr_code_token, total_amount, platform_fee, net_owner_amount)
SELECT st.rest_stop_id, u.user_id, DATE '2026-09-12', '—', 1, 1, 'completed', 'RD-8831', 'RD-8831-QR', 0, 0, 0
  FROM rd_rest_stops st, rd_users u
 WHERE st.name = 'محطة كدي المركزية' AND u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_bookings x WHERE x.booking_code = 'RD-8831');

INSERT INTO rd_bookings (rest_stop_id, driver_id, booking_date, arrival_time, bus_count, people_count, status, booking_code, qr_code_token, total_amount, platform_fee, net_owner_amount)
SELECT st.rest_stop_id, u.user_id, DATE '2026-09-09', '—', 1, 1, 'completed', 'RD-7720', 'RD-7720-QR', 0, 0, 0
  FROM rd_rest_stops st, rd_users u
 WHERE st.name = 'محطة حافلات جدة' AND u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_bookings x WHERE x.booking_code = 'RD-7720');

INSERT INTO rd_bookings (rest_stop_id, driver_id, booking_date, arrival_time, bus_count, people_count, status, booking_code, qr_code_token, total_amount, platform_fee, net_owner_amount)
SELECT st.rest_stop_id, u.user_id, DATE '2026-09-04', '—', 1, 1, 'completed', 'RD-6512', 'RD-6512-QR', 0, 0, 0
  FROM rd_rest_stops st, rd_users u
 WHERE st.name = 'محطة المروة' AND u.email = 'campaign@anwar.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_bookings x WHERE x.booking_code = 'RD-6512');

-- 8) طلب الوجبات #ORD-8821 (95 وجبة غداء × 25 = 2,375 ر.س) على محطة واحة النخيل
INSERT INTO rd_meal_orders (order_code, campaign_id, rest_stop_id, meal_id, meal_name, quantity, total, status)
SELECT 'ORD-8821', u.user_id, st.rest_stop_id, m.meal_id, 'وجبة غداء', 95, 2375, 'PAID'
  FROM rd_users u, rd_rest_stops st, rd_meals m
 WHERE u.email = 'campaign@alwifada.sa' AND st.name = 'محطة واحة النخيل' AND m.meal_name = 'وجبة غداء'
   AND NOT EXISTS (SELECT 1 FROM rd_meal_orders x WHERE x.order_code = 'ORD-8821');

-- معاملة الطلب: صافي المحطة 85% = 2,018.75 ورسوم المنصة 15% = 356.25 (كما في شاشة المحطة)
INSERT INTO rd_transactions (order_id, campaign_owner_id, rest_stop_owner_id, total_amount, platform_percentage, platform_profit, owner_payout, transaction_type)
SELECT o.order_id, o.campaign_id, st.owner_id, 2375, 15, 356.25, 2018.75, 'MEAL'
  FROM rd_meal_orders o JOIN rd_rest_stops st ON st.rest_stop_id = o.rest_stop_id
 WHERE o.order_code = 'ORD-8821'
   AND NOT EXISTS (SELECT 1 FROM rd_transactions t WHERE t.order_id = o.order_id);

-- 9) قيود المحفظة (Ledger) كما تظهر في شاشة المحطة
INSERT INTO rd_wallet_ledger (user_id, amount, reason, ref_code)
SELECT u.user_id, 2018.75, 'إيداع مبيعات وجبات', 'ORD-8821' FROM rd_users u
 WHERE u.email = 'owner@nakheel.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_wallet_ledger l WHERE l.user_id = u.user_id AND l.ref_code = 'ORD-8821' AND l.amount = 2018.75);

INSERT INTO rd_wallet_ledger (user_id, amount, reason, ref_code)
SELECT u.user_id, 127.50, 'رسوم توقف ومسار حافلة VIP', NULL FROM rd_users u
 WHERE u.email = 'owner@nakheel.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_wallet_ledger l WHERE l.user_id = u.user_id AND l.reason = 'رسوم توقف ومسار حافلة VIP');

INSERT INTO rd_wallet_ledger (user_id, amount, reason, ref_code)
SELECT u.user_id, 425.00, 'حجز صالة استراحة خاصة', NULL FROM rd_users u
 WHERE u.email = 'owner@nakheel.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_wallet_ledger l WHERE l.user_id = u.user_id AND l.reason = 'حجز صالة استراحة خاصة');

INSERT INTO rd_wallet_ledger (user_id, amount, reason, ref_code)
SELECT u.user_id, -2375, 'خصم وجبات من محفظة الحملة', 'ORD-8821' FROM rd_users u
 WHERE u.email = 'campaign@alwifada.sa'
   AND NOT EXISTS (SELECT 1 FROM rd_wallet_ledger l WHERE l.user_id = u.user_id AND l.ref_code = 'ORD-8821');

COMMIT;
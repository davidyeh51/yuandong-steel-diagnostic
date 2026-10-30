-- ==============================================================================
-- 遠東鋼鐵一~三期 1,481.8kWp 8D 異常診斷資料寫入腳本 (Supabase SQL)
-- 適用於 Supabase PostgreSQL 資料庫執行（2026/10/30 核定更新版）
-- ==============================================================================

-- 1. 新增/更新電廠資料 (plants)
INSERT INTO public.plants (
    plant_code,
    name,
    plant_type,
    location,
    lat,
    lng,
    contract_kw,
    actual_capacity_kwp,
    total_modules,
    inverter_model,
    inverter_count,
    fit_rate,
    owner_name
) VALUES (
    'KH01',
    '遠東鋼鐵一~三期屋頂型光電電廠',
    '屋頂型',
    '812 高雄市小港區店鎮里嘉興街 8 號（北林路口）',
    22.561446,
    120.365215,
    1400.0,
    1481.800,
    4780,
    'DELTA RPI-M30A (45台，30kW 雙MPPT) / URE D6M310H3A (310Wp 4,780片)',
    45,
    5.15,
    '高雄遠東鋼鐵股份有限公司'
) ON CONFLICT (plant_code) DO UPDATE SET
    location = EXCLUDED.location,
    lat = EXCLUDED.lat,
    lng = EXCLUDED.lng,
    actual_capacity_kwp = EXCLUDED.actual_capacity_kwp,
    total_modules = EXCLUDED.total_modules,
    inverter_model = EXCLUDED.inverter_model,
    fit_rate = EXCLUDED.fit_rate,
    updated_at = NOW();

-- 2. 新增/更新 8D 報告主表 (reports_8d)
WITH target_plant AS (
    SELECT id FROM public.plants WHERE plant_code = 'KH01' LIMIT 1
)
INSERT INTO public.reports_8d (
    plant_id,
    case_no,
    report_title,
    report_version,
    publish_date,
    year,
    data_period,
    stage,
    severity_level,
    abnormal_device,
    ratio_to_benchmark,
    loss_kwh,
    annual_loss_ntd,
    priority_issue,
    lede,
    takeaway,
    report_url
) VALUES (
    (SELECT id FROM target_plant),
    'PV-2026-KH01',
    '高雄小港遠東鋼鐵一~三期 1,481.8kWp｜8D 性能異常診斷暨效益改善決策報告',
    'v1.1 (2026/10/30 核定更新版)',
    CURRENT_DATE,
    2026,
    '2025/10/06 – 2026/10/05（365天，併聯日 2019/04/13）',
    'd5_permanent_actions',
    'Level 2 (重大發電異常與火載量隱患)',
    'INV026, INV014, INV030 (全場共 31 台落後)',
    0.762,
    192864,
    993247,
    '小港鋼粉重度落塵覆蓋、冬季低仰角氣樓遮陰、INV014雙MPPT單串斷路與INV030跳脫',
    '全場 45 台 DELTA RPI-M30A 年度發電量僅 156 萬度 (平均 DY 2.89)，相比標竿機台 INV037 (DY 3.241) 全年短少 192,864 度電 (年損電費 NT$ 99.3 萬元，以綠電 5.15 元/度計)。診斷確診為重工業鋼粉落塵覆蓋、太子樓冬季低仰角遮蔽、INV014 雙MPPT單串斷路與 INV030 跳脫 16 天。整改預算 3,803,328 元，3.83 年回本，合約剩餘 12.5 年累計回補 1,241.6 萬元，扣除整改成本淨增值高達 861.2 萬元！',
    '實施五大精準修繕工項：DELTA M30A 直流斷路修復、風道與通訊檢修、超高壓物理除垢自潔鍍膜、遮陰跳線重組與即時 P2P 邊緣告警，確保日等價時數自 2.89 飛躍至 3.241，全面保障 12.5 年合約收益！',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/'
) ON CONFLICT (case_no) DO UPDATE SET
    loss_kwh = EXCLUDED.loss_kwh,
    annual_loss_ntd = EXCLUDED.annual_loss_ntd,
    lede = EXCLUDED.lede,
    takeaway = EXCLUDED.takeaway,
    report_url = EXCLUDED.report_url,
    updated_at = NOW();

-- 3. 新增工單資料表支援 (work_orders)
CREATE TABLE IF NOT EXISTS public.work_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_no VARCHAR(64) NOT NULL,
    plant_name VARCHAR(255) NOT NULL,
    signer_name VARCHAR(128) NOT NULL,
    signer_contact VARCHAR(128) NOT NULL,
    budget_ntd NUMERIC(12, 2) DEFAULT 3803328.00,
    fit_rate NUMERIC(6, 2) DEFAULT 5.15,
    schedule_notes TEXT,
    notes TEXT,
    status VARCHAR(32) DEFAULT 'pending_approval',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允許公開訪客或客戶在線提交整改工單"
    ON public.work_orders FOR INSERT
    WITH CHECK (true);

CREATE POLICY "允許已認證維運人員讀取工單"
    ON public.work_orders FOR SELECT
    USING (true);


-- ------------------------------------------------------------------------------
-- 4. CAD/BIM 竣工圖資資料表支援 (plant_drawings)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.plant_drawings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plant_code VARCHAR(64) NOT NULL,
    phase_no INTEGER NOT NULL,                   -- 1, 2, 3
    drawing_code VARCHAR(32) UNIQUE NOT NULL,    -- EV-DWG-01 ~ 06
    category VARCHAR(64) NOT NULL,               -- 屋頂配置圖 / 直流串列圖
    file_name VARCHAR(128) NOT NULL,
    storage_path TEXT,
    public_url TEXT NOT NULL,
    capacity_kwp NUMERIC(10, 3),
    inverter_model VARCHAR(128) DEFAULT 'DELTA RPI-M30A (30kW 雙MPPT)',
    inverter_count INTEGER DEFAULT 15,
    modules_per_string INTEGER DEFAULT 21,
    strings_per_inverter INTEGER DEFAULT 5,
    mppt_config TEXT DEFAULT 'MPPT1 (3串並聯 = 28.1A) ｜ MPPT2 (2串並聯 = 18.7A)',
    shading_exposure TEXT,
    noise_mechanism_notes TEXT,
    reconfiguration_solution TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.plant_drawings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允許公開查詢電廠竣工圖資"
    ON public.plant_drawings FOR SELECT
    USING (true);

-- 寫入遠東鋼鐵一~三期 6 大竣工圖資與電氣分析
INSERT INTO public.plant_drawings (
    plant_code,
    phase_no,
    drawing_code,
    category,
    file_name,
    storage_path,
    public_url,
    capacity_kwp,
    inverter_count,
    shading_exposure,
    noise_mechanism_notes,
    reconfiguration_solution
) VALUES 
(
    'KH01', 1, 'EV-DWG-01', '屋頂配置圖', 'phase1_layout.png',
    'drawings/phase1_layout.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase1_layout.png',
    488.250, 15,
    '北林路側廠房屋頂，中央設有長條形通風氣樓 (太子樓)，冬季低日照仰角投射長陰影至鄰近 1~2 串列。',
    '無電氣雜訊，主要反映廠房屋面建築幾何與通風太子樓空間物理障礙。',
    '無'
),
(
    'KH01', 1, 'EV-DWG-02', '直流串列圖', 'phase1_string.png',
    'drawings/phase1_string.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase1_string.png',
    488.250, 15,
    '每台 M30A 連接 5 串 (1+1~1+5 等)，每串 21 片 (Vmp=695V)。MPPT1 接 3 串，MPPT2 接 2 串。',
    '【噪音完全屬實】MPPT1 接入 3 串中若有 1 串受氣樓遮蔽，引發 MPPT Hunting 獵頻震盪，Boost 電感磁致震盪產生 1~4kHz 刺耳哨叫；且 28A 重載引發散熱風扇 100% 滿轉速 (6,000 RPM) 共振尖叫。',
    '【串列重組增益】將受遮陰 2 串獨立跳線接入 MPPT2，全日照 3 串接入 MPPT1，消除獵頻震盪，噪音降 15~20 dB(A)，發電效率提升 +5.7%~9.8%。'
),
(
    'KH01', 2, 'EV-DWG-03', '屋頂配置圖', 'phase2_layout.png',
    'drawings/phase2_layout.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase2_layout.png',
    488.250, 15,
    '廠房屋面中間跨距，局部受氣樓及屋脊女兒牆遮蔽，INV030 過溫跳脫台所在地。',
    '反映廠房高低屋面落差與局部通風風向，鋼粉落塵在二期屋面背風側沉降濃度偏高。',
    '無'
),
(
    'KH01', 2, 'EV-DWG-04', '直流串列圖', 'phase2_string.png',
    'drawings/phase2_string.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase2_string.png',
    488.250, 15,
    '每台 M30A 連接 5 串 (16+1~16+5 等)，每串 21 片 (Vmp=695V)。INV030 曾因散熱不良過溫跳脫 16 天。',
    '【噪音完全屬實】二期屋面鐵粉覆蓋較重，INV030 散熱鰭片嚴重阻塞，風扇滾珠軸承嚴重磨損尖叫，觸發內部過溫斷路。',
    '更換原廠全新密封雙滾珠散熱風扇，乾冰除碳吹洗散熱片；實施陰陽串列解耦，杜絕 MPPT 電壓拉扯。'
),
(
    'KH01', 3, 'EV-DWG-05', '屋頂配置圖', 'phase3_layout.png',
    'drawings/phase3_layout.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase3_layout.png',
    505.300, 15,
    '全場日照條件最佳之開闊屋頂，無高大通風氣樓遮陰，全場發電標竿 INV037 (DY 3.241, PR 78.71%) 即座落於此。',
    '無遮陰障礙，為全場發電之天花板基準。',
    '施加奈米二氧化鈦光觸媒自潔塗層，將 DY 突破拉抬至 3.35~3.42，每日創造 +125 kWh 淨富餘發電量以代償一、二期受限區。'
),
(
    'KH01', 3, 'EV-DWG-06', '直流串列圖', 'phase3_string.png',
    'drawings/phase3_string.png',
    'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase3_string.png',
    505.300, 15,
    '直流串列 DC1-1 ~ DC15-5，每串 20~21 片。運轉健康度極佳。',
    '三期背景噪音正常，因日照均勻無局部陰影，MPPT 未出現獵頻震盪，印證一二期噪音確為陰影失配引起之推論！',
    '維持標準健康維運，加強直流端子紅外線熱像檢測與防塵吹洗。'
) ON CONFLICT (drawing_code) DO UPDATE SET
    public_url = EXCLUDED.public_url,
    shading_exposure = EXCLUDED.shading_exposure,
    noise_mechanism_notes = EXCLUDED.noise_mechanism_notes,
    reconfiguration_solution = EXCLUDED.reconfiguration_solution;

-- 5. 同步寫入 8D 證據資料庫 (report_evidences)
WITH target_report AS (
    SELECT id FROM public.reports_8d WHERE case_no = 'PV-2026-KH01' LIMIT 1
)
INSERT INTO public.report_evidences (
    report_id, ev_code, category, title, description, step_tag, image_url, storage_path, taken_at, uploader
) VALUES 
(
    (SELECT id FROM target_report), 'EV-DWG-01', '施工圖紙', '遠東鋼鐵一期屋頂配置圖 (15台 / 488.25kWp)',
    '北林路側廠房屋頂幾何配置，中央長條形通風氣樓 (太子樓) 為冬季低日照仰角陰影主要來源。',
    'D4', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase1_layout.png',
    'drawings/phase1_layout.png', '2026/10/30', '進金生機電工程組'
),
(
    (SELECT id FROM target_report), 'EV-DWG-02', '施工圖紙', '遠東鋼鐵一期直流串列圖 (DELTA M30A 雙MPPT)',
    '竣工電氣串接顯示每台接 5 串 (21片/串)，MPPT1 採 3 串並聯 (28.1A)，MPPT2 採 2 串並聯 (18.7A)。確診單串遮陰引發 MPPT Hunting 獵頻震盪為電感磁致震盪哨叫噪音之根本成因。',
    'D4', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase1_string.png',
    'drawings/phase1_string.png', '2026/10/30', '進金生機電工程組'
),
(
    (SELECT id FROM target_report), 'EV-DWG-03', '施工圖紙', '遠東鋼鐵二期屋頂配置圖 (15台 / 488.25kWp)',
    '廠房屋面中間跨距配置，背風側鋼粉落塵較重，局部受氣樓與女兒牆遮蔽。',
    'D4', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase2_layout.png',
    'drawings/phase2_layout.png', '2026/10/30', '進金生機電工程組'
),
(
    (SELECT id FROM target_report), 'EV-DWG-04', '施工圖紙', '遠東鋼鐵二期直流串列圖 (INV030 跳脫所在地)',
    '二期 15 台變流器串列配置，INV030 因散熱不良觸發過溫跳脫 16 天，透過串列重組與更換密封風扇徹底解決。',
    'D5', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase2_string.png',
    'drawings/phase2_string.png', '2026/10/30', '進金生機電工程組'
),
(
    (SELECT id FROM target_report), 'EV-DWG-05', '施工圖紙', '遠東鋼鐵三期屋頂配置圖 (標竿 INV037 座落地)',
    '全場開闊無遮陰最佳屋面 (505.30kWp)，日照條件最優越，作為 Zone A 天花板超額代償區之發電火車頭。',
    'D6', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase3_layout.png',
    'drawings/phase3_layout.png', '2026/10/30', '進金生機電工程組'
),
(
    (SELECT id FROM target_report), 'EV-DWG-06', '施工圖紙', '遠東鋼鐵三期直流串列圖 (DC1-1 ~ DC15-5)',
    '三期 15 台變流器直流串接圖，PR 達 78.71% 全場最高，印證無陰影失配時 DELTA M30A 運轉無噪音之推論。',
    'D6', 'https://davidyeh51.github.io/yuandong-steel-diagnostic/assets/drawings/phase3_string.png',
    'drawings/phase3_string.png', '2026/10/30', '進金生機電工程組'
) ON CONFLICT (ev_code) DO NOTHING;

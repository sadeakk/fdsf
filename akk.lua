--[[
    SMART KAITUN — FALL HARVEST (versi ringkas)
    Hanya: beli seed -> jual (SellAll), diulang terus, ditambah FPS boost,
    anti-AFK, dan black-screen HUD. Menanam, memanen, mencabut, quest,
    mode bambu, kolektor seed jatuhan, sinkronisasi panel, dan sistem
    pindah-dunia SUDAH DIHAPUS dari versi ini -- lihat riwayat git kalau
    perlu mengembalikannya.

    Signature remote yang masih dipakai, ditangkap dari klien asli:
      SeedShop.PurchaseSeed:Fire("Maple Carrot")
      NPCS.PreviewSellAll()  lalu  NPCS.SellAll()               -- tanpa argumen

    Jebakan yang cuma ketahuan dari data asli:
      Jual butuh staging: PreviewSellAll dipanggil lebih dulu, kalau tidak
      server menolak diam-diam.

    Soal jarak: panen/tanam/jual/cabut terbukti diterima dari jarak jauh, tapi
    itu tidak lagi relevan di versi ini kecuali untuk JUAL (opsional lewat
    Config.DekatSaatJual). Yang WAJIB mendekat tinggal MEMBELI: PurchaseSeed
    dari jauh tetap diterima, tapi anticheat menandainya dan ban menyusul
    belakangan. Karena itu jalur beli tidak punya opsi untuk dimatikan, dan
    kalau NPC-nya tak tercapai, pembelian dibatalkan seluruhnya.

    Geraknya sendiri memakai BodyVelocity berkecepatan tetap (default 22 studs/s).
    Versi pertama memakai BodyPosition yang menarik dengan gaya besar sehingga
    karakter melesat -- terlihat jelas tidak wajar.
]]

-- ==========================================
-- PANEL KEY (verifikasi HWID/Discord dihapus)
-- ==========================================
-- Dulu di sini ada gerbang verifikasi HWID lewat ABASUWframe.my.id yang bisa
-- nge-kick kalau key kosong/tidak valid, plus sinkronisasi ke panel web.
-- Keduanya sudah dicopot -- script ini jalan berdiri sendiri, tanpa key dan
-- tanpa menghubungi server luar mana pun.
local cfgFH  = getgenv().ABASUWFallHarvestConfig or {}
local cfgMain = getgenv().ABASUWAutoBuyConfig or {}
local cfg = cfgFH
print("✅ Kaitun aktif (verifikasi panel key dinonaktifkan)")
-- ==========================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LocalPlayer        = Players.LocalPlayer

local Config = {
    -- Master switch. Dua sumber sengaja digabung: cfgFH (ABASUWFallHarvestConfig)
    -- untuk toggle khusus script ini, cfgMain (ABASUWAutoBuyConfig) untuk format
    -- config yang sudah dipakai panel/loader lain (BuySeeds/BuyGears/Seeds/Gears).
    AutoBeli      = (cfg.AutoBeli ~= false) and (cfgMain.BuySeeds ~= false),
    AutoBeliGear  = (cfg.AutoBeliGear == true) or (cfgMain.BuyGears == true),
    AutoJual      = cfg.AutoJual ~= false,
    -- Daily Deal diklaim SEBELUM SellAll -- lihat jual(). Buah yang termasuk
    -- daily deal dapat bonus lewat jalur ini; kalau SellAll jalan duluan,
    -- buahnya sudah terjual biasa dan bonusnya hilang.
    DailyDeal     = (cfg.DailyDeal ~= false) and (cfgMain.DailyDeal ~= false),

    -- Daftar putih per-nama: { ["Nama Item"] = true/false }. nil (tidak diisi
    -- sama sekali) berarti TIDAK ada penyaringan -- beli semua yang ada di rak,
    -- seperti sebelumnya. Kalau diisi, hanya nama dengan nilai `true` yang dibeli;
    -- item lain (termasuk yang `false` atau tidak disebut) dilewati.
    SeedWhitelist = cfgMain.Seeds,
    GearWhitelist = cfgMain.Gears,

    FpsBoost      = cfg.FpsBoost ~= false,
    BlackScreen   = cfg.BlackScreen ~= false,
    AntiAFK       = cfg.AntiAFK ~= false,

    -- Batas frame. Sasarannya perangkat yang menjalankan beberapa klien Roblox
    -- sekaligus -- di sana render adalah pemakan CPU terbesar, sedangkan bot
    -- tidak butuh frame tinggi sama sekali. Terukur: 125 fps -> 19 fps.
    -- Set 0 untuk mematikan pembatasan sepenuhnya.
    BatasFps      = (function()
        local v = tonumber(cfg.BatasFps) or 20
        if v <= 0 then return 0 end
        return math.max(10, math.min(240, v))
    end)(),

    -- Jeda antar koreksi arah saat terbang ke NPC (pergiKe). TIDAK diikat ke
    -- RunService.Heartbeat lagi -- di perangkat yang menjalankan banyak
    -- executor sekaligus (mis. 10 akun cloud phone), tiap akun memaksa loop
    -- ini berjalan di laju render penuh SECARA BERSAMAAN, dan itu cukup berat
    -- untuk membuat sebagian executor force-close. 0.1 detik (10x/detik)
    -- masih cukup halus untuk kecepatan terbang default (22 studs/detik).
    JedaGerak     = tonumber(cfg.JedaGerak) or 0.1,
    -- Kebun orang lain dimuat bertahap seiring pemain berdatangan, jadi
    -- pembersihannya diulang. Murah (~1,2 ms, hanya menyentuh Gardens).
    SiklusBersihKebun = tonumber(cfg.SiklusBersihKebun) or 5,

    JedaSiklus    = tonumber(cfg.JedaSiklus) or 5,
    -- cfgMain.Delay ("Jeda loop auto buy") didahulukan supaya format config
    -- yang kamu tempel dari panel langsung berlaku tanpa perlu isi cfgFH juga.
    JedaAksi      = tonumber(cfgMain.Delay) or tonumber(cfg.JedaAksi) or 0.35,

    JarakAman     = tonumber(cfg.JarakAman) or 12,
    MaxBeliPerSiklus = tonumber(cfg.MaxBeliPerSiklus) or 20,

    -- studs/detik. Versi pertama memakai BodyPosition yang menarik dengan gaya
    -- besar, jadi karakter melesat ke tujuan -- terlihat jelas tidak wajar.
    KecepatanTerbang = tonumber(cfg.KecepatanTerbang) or 22,

    -- SellAll terbukti diterima dari jarak jauh, jadi mendekat ke Steven
    -- opsional saja. Default mati.
    DekatSaatJual  = cfg.DekatSaatJual == true,

    -- Peta ini penuh batu dan penghalang. Tanpa noclip, terbang lurus sering
    -- tersangkut dan karakter berhenti di tengah jalan.
    Noclip        = cfg.Noclip ~= false,

    -- Menunggu dunia siap TIDAK bisa dimatikan lewat config -- disengaja.
    -- Script ini dipakai tanpa pengawasan di cloud phone, jadi tidak boleh ada
    -- jalur yang membuatnya menembak beli/jual sebelum karakter dan dunia
    -- benar-benar termuat hanya karena config salah ketik. Hanya angka
    -- waktunya yang bisa diatur, bukan on/off-nya.
    MaksTungguSiap  = tonumber(cfg.MaksTungguSiap) or 60,
    JedaKlikSiap    = tonumber(cfg.JedaKlikSiap) or 1.5,
}

local function status(t)
    _G.FallHarvestDebug = t
    print("[FH] " .. t)
end

local okNet, Networking = pcall(function()
    return require(ReplicatedStorage.SharedModules.Networking)
end)
if not okNet then
    status("[BERHENTI] Gagal me-require Networking module.")
    return
end

-- ==========================================================
-- TUNGGU GAME SIAP
-- ==========================================================
-- Dua strategi digabung, keduanya generik karena nama GUI animasi home/intro
-- dunia ini belum terverifikasi dari klien asli:
--   1. Klik tengah layar berkala -- kebanyakan tombol "Play"/pop-up tutorial
--      duduk di tengah, dan klik tidak merusak apa pun kalau ternyata tidak
--      ada yang perlu diklik.
--   2. Anggap "siap" begitu karakter (HumanoidRootPart+Humanoid), leaderstats
--      Leaves, dan folder dunia (Gardens/NPCS) semuanya sudah ada -- itu bukti
--      langsung sesi sudah masuk gameplay sungguhan, bukan sekadar menebak
--      berapa lama animasinya berjalan.
local function klikTengahLayar()
    local vim = game:GetService("VirtualInputManager")
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
    local x, y = vp.X / 2, vp.Y / 2
    pcall(function()
        vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
end

local function duniaSudahSiap()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local daun = ls and ls:FindFirstChild("Leaves")
    return hrp ~= nil and hum ~= nil and daun ~= nil
        and workspace:FindFirstChild("Gardens") ~= nil
        and workspace:FindFirstChild("NPCS") ~= nil
end

-- Selalu berjalan, tanpa jalur mati -- lihat catatan di Config.MaksTungguSiap
-- soal kenapa ini bukan toggle.
local function tungguGameSiap()
    status("[SIAP] Menunggu dunia termuat...")

    local berhenti = false
    task.spawn(function()
        while not berhenti do
            klikTengahLayar()
            task.wait(Config.JedaKlikSiap)
        end
    end)

    local batas = tick() + Config.MaksTungguSiap
    while tick() < batas and not duniaSudahSiap() do
        task.wait(0.5)
    end
    berhenti = true

    if duniaSudahSiap() then
        status("[SIAP] Dunia siap")
    else
        -- Setiap pemanggilan remote/baca state lain di script ini sudah
        -- dibungkus pcall/pengecekan nil sendiri-sendiri, jadi melanjutkan
        -- walau timeout tetap aman -- hanya berarti fase pertama mungkin
        -- gagal dan dicoba lagi siklus berikutnya.
        status("[SIAP] Timeout menunggu — lanjut jalan seadanya")
    end
end

-- ==========================================================
-- GERAK
-- ==========================================================
local function karakter()
    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return c, hrp, hum
end

local function jarakKe(pos)
    local _, hrp = karakter()
    if not hrp then return math.huge end
    return (hrp.Position - pos).Magnitude
end

-- Terbang ke tujuan dengan KECEPATAN TETAP.
--
-- Versi pertama memakai BodyPosition: gaya tariknya besar sehingga karakter
-- melesat dan geraknya tidak wajar. BodyVelocity dengan besaran tetap membuat
-- kecepatannya benar-benar terkendali -- arahnya saja yang diperbarui tiap
-- frame. MaxForce pada sumbu Y sekaligus menahan gravitasi.
-- Noclip: hanya part yang MEMANG tadinya menabrak yang dimatikan, dan persis
-- part itu pula yang dipulihkan. Mematikan semua lalu menyalakan semua akan
-- mengubah part yang aslinya sudah CanCollide=false (HumanoidRootPart, aksesori)
-- dan itu bisa merusak fisika karakter setelah terbang.
local function matikanTabrakan()
    local c = LocalPlayer.Character
    if not c then return {} end
    local disimpan = {}
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            disimpan[#disimpan + 1] = p
            p.CanCollide = false
        end
    end
    return disimpan
end

local function pulihkanTabrakan(disimpan)
    for _, p in ipairs(disimpan) do
        if p.Parent then p.CanCollide = true end
    end
end

local function pergiKe(pos, toleransi)
    toleransi = toleransi or Config.JarakAman
    local _, hrp = karakter()
    if not hrp then return false end

    local tujuan = pos + Vector3.new(0, 3, 0)
    if (hrp.Position - pos).Magnitude <= toleransi then return true end

    -- Batas waktu dihitung dari jarak dan kecepatan, bukan angka tetap: dengan
    -- 22 studs/detik, tujuan 150 studs butuh ~7 detik, dan batas mati 20 detik
    -- akan memutus perjalanan yang sebenarnya sehat.
    local perkiraan = (hrp.Position - tujuan).Magnitude / math.max(1, Config.KecepatanTerbang)
    local batas = tick() + perkiraan * 2 + 5

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local dimatikan = Config.Noclip and matikanTabrakan() or {}

    while tick() < batas do
        local _, h2 = karakter()
        if not h2 then break end
        local selisih = tujuan - h2.Position
        if (h2.Position - pos).Magnitude <= toleransi then break end
        bv.Velocity = selisih.Unit * Config.KecepatanTerbang
        -- Diterapkan ulang tiap denyut: Roblox mengembalikan CanCollide sendiri
        -- pada beberapa keadaan, dan sekali saja di awal tidak cukup.
        if Config.Noclip then
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(dimatikan) do
                    if p.Parent and p.CanCollide then p.CanCollide = false end
                end
            end
        end
        -- task.wait(Config.JedaGerak), BUKAN RunService.Heartbeat:Wait().
        --
        -- Heartbeat berdetak sekali per frame yang dirender -- kalau kamu
        -- menjalankan banyak executor sekaligus di satu perangkat (mis. 10
        -- akun cloud phone), tiap akun memaksakan loop Lua ini berjalan di
        -- kecepatan render penuh SECARA BERSAMAAN, dan itu bisa membebani CPU
        -- sampai sebagian executor force-close. Fisika BodyVelocity tetap
        -- disimulasikan mesin fisika terlepas dari seberapa sering kita
        -- memperbarui arahnya, jadi menurunkan lajunya ke interval tetap tidak
        -- mengurangi kehalusan gerak -- cuma mengurangi berapa kali skrip ini
        -- ikut jalan tiap detik.
        task.wait(Config.JedaGerak)
    end

    bv:Destroy()
    pulihkanTabrakan(dimatikan)

    -- Tunggu mendarat sebelum menyerahkan kendali, supaya aksi berikutnya
    -- (equip/fire remote) tidak dilakukan saat karakter masih melayang.
    local tungguDarat = tick() + 4
    while tick() < tungguDarat do
        local _, h3, hum3 = karakter()
        if not (h3 and hum3) then break end
        if hum3:GetState() == Enum.HumanoidStateType.Running
           and h3.AssemblyLinearVelocity.Magnitude < 3 then
            break
        end
        task.wait(0.1)
    end

    task.wait(0.2)
    if jarakKe(pos) <= toleransi * 1.5 then return true end

    -- FALLBACK: terbang gagal sampai (fisika/FPS bisa macet di cloud phone).
    -- Server hanya memeriksa JARAK saat remote ditembak, bukan bagaimana
    -- caranya sampai di situ, jadi memindahkan CFrame langsung ke dekat
    -- tujuan tetap memenuhi syarat yang sama seperti terbang berhasil --
    -- tanpa ini, gagal terbang berarti pembelian dibatalkan seluruhnya
    -- padahal seharusnya bisa lanjut.
    local _, hrp2 = karakter()
    if not hrp2 then return false end
    pcall(function()
        hrp2.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
    task.wait(0.3)
    return jarakKe(pos) <= toleransi * 1.5
end

-- ==========================================================
-- PLOT (dipakai FPS boost untuk melindungi kebun sendiri)
-- ==========================================================
-- Mengembalikan kebun milik kita, atau nil kalau BENAR-BENAR tidak bisa
-- dipastikan. Pemanggil WAJIB memperlakukan nil sebagai "jangan sentuh apa pun",
-- bukan sebagai "tidak ada yang perlu dilindungi" -- lihat applyFpsBoost.
local function plotSaya()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end

    -- 1. Atribut pemilik, kalau game memang menyediakannya.
    for _, g in ipairs(gardens:GetChildren()) do
        for _, kunci in ipairs({ "OwnerUserId", "UserId", "Owner", "OwnerId", "PlayerUserId" }) do
            if tostring(g:GetAttribute(kunci)) == tostring(LocalPlayer.UserId) then return g end
        end
    end

    -- 2. Cadangan lewat nama tanaman "{userId}_{guid}". Format ini sudah
    --    diverifikasi di server sungguhan, sedangkan atribut di atas TIDAK --
    --    dan mengandalkan atribut saja pernah membuat seluruh kebun terhapus.
    local uid = tostring(LocalPlayer.UserId)
    for _, g in ipairs(gardens:GetChildren()) do
        local plants = g:FindFirstChild("Plants")
        if plants then
            for _, t in ipairs(plants:GetChildren()) do
                if string.match(t.Name, "^(%d+)_") == uid then return g end
            end
        end
    end

    -- 3. Cadangan terakhir: kebun orang lain memasang StealPrompt, kebun sendiri
    --    memakai HarvestPrompt.
    for _, g in ipairs(gardens:GetChildren()) do
        local plants = g:FindFirstChild("Plants")
        if plants and #plants:GetChildren() > 0 then
            local adaSteal = false
            for _, t in ipairs(plants:GetChildren()) do
                local hp = t:FindFirstChild("HarvestPart")
                if hp and hp:FindFirstChild("StealPrompt") then adaSteal = true break end
            end
            if not adaSteal then return g end
        end
    end

    return nil
end

-- ==========================================================
-- BLACK SCREEN + HUD STATUS
-- ==========================================================
_G.FHRiwayat = _G.FHRiwayat or {}

local function catatRiwayat(teks)
    table.insert(_G.FHRiwayat, 1, teks)
    -- Dibatasi 8 baris: kotaknya tidak bisa di-scroll, jadi menyimpan lebih
    -- banyak hanya membuat baris terbawah terpotong tanpa pernah terbaca.
    while #_G.FHRiwayat > 8 do table.remove(_G.FHRiwayat) end
end

-- Dipakai HUD (label Leaves) maupun checkpoint 5-menit -- satu fungsi supaya
-- keduanya tidak bisa berbeda format. Menangani negatif juga (checkpoint bisa
-- menampilkan selisih minus kalau Leaves berkurang).
local function ringkasAngka(n)
    n = tonumber(n) or 0
    local tanda = n < 0 and "-" or ""
    local a = math.abs(n)
    if a >= 1e12 then return tanda .. string.format("%.2fT", a / 1e12)
    elseif a >= 1e9 then return tanda .. string.format("%.2fB", a / 1e9)
    elseif a >= 1e6 then return tanda .. string.format("%.2fM", a / 1e6)
    elseif a >= 1e3 then return tanda .. string.format("%.1fK", a / 1e3)
    else return tostring(n) end
end

-- Ringkasan tas untuk panel HUD kiri/kanan. Dibedakan lewat ATRIBUT tool,
-- bukan nama -- sama seperti dipakai di seluruh script ini (SeedTool untuk
-- seed, Sprinkler/WateringCan untuk gear). Shovel/Build sengaja dilewati:
-- dimiliki semua pemain, jadi menampilkannya cuma "Shovel x1" tanpa arti.
local function bacaInventoryRingkas()
    local seedMap, gearMap = {}, {}
    for _, wadah in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
        if wadah then
            for _, t in ipairs(wadah:GetChildren()) do
                if t:IsA("Tool") then
                    local seedName = t:GetAttribute("SeedTool")
                    local gearName = t:GetAttribute("Sprinkler") or t:GetAttribute("WateringCan")
                    if seedName then
                        seedMap[seedName] = (seedMap[seedName] or 0) + (tonumber(t:GetAttribute("Count")) or 1)
                    elseif gearName then
                        gearMap[gearName] = (gearMap[gearName] or 0) + 1
                    end
                end
            end
        end
    end
    return seedMap, gearMap
end

local function formatInventoryHUD(map, simbol)
    local baris = {}
    for nama, jumlah in pairs(map) do
        baris[#baris + 1] = string.format("%s %s x%d", simbol, nama, jumlah)
    end
    if #baris == 0 then return "(kosong)" end
    table.sort(baris)
    return table.concat(baris, "\n")
end

local function pasangBlackScreen()
    if not Config.BlackScreen then return end

    -- Re-run di sesi yang sama (loadstring dijalankan ulang tanpa rejoin)
    -- meninggalkan GUI lama menggantung kalau tidak dibersihkan -- dua HUD
    -- bertumpuk, dua tombol toggle, dan dua loop update jalan bersamaan.
    -- Menghapus gui lama juga otomatis menghentikan loop update-nya, karena
    -- loop itu berhenti sendiri begitu gui.Parent bernilai nil.
    do
        -- Dibangun lewat table.insert, BUKAN literal {a, b, c}: kalau gethui
        -- tidak ada di executor ini, entri pertamanya nil, dan ipairs BERHENTI
        -- di nil pertama -- CoreGui/PlayerGui di belakangnya tidak akan pernah
        -- diperiksa sama sekali.
        local tempatGui = {}
        local okGethui, hui = pcall(function() return gethui and gethui() end)
        if okGethui and hui then table.insert(tempatGui, hui) end
        table.insert(tempatGui, game:GetService("CoreGui"))
        local pgLama = LocalPlayer:FindFirstChild("PlayerGui")
        if pgLama then table.insert(tempatGui, pgLama) end

        for _, wadah in ipairs(tempatGui) do
            local lama = wadah:FindFirstChild("AFK_BlackScreen")
            if lama then pcall(function() lama:Destroy() end) end
        end
    end

    local ok = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "AFK_BlackScreen"
        gui.Enabled = true
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BorderSizePixel = 0
        bg.Parent = gui

        -- Tombol toggle. Sengaja anak GUI langsung, BUKAN anak `bg` -- kalau
        -- ditaruh di dalam bg, tombolnya ikut tersembunyi begitu bg disembunyikan
        -- dan tidak ada cara menampilkannya lagi selain rejoin.
        local tombolToggle = Instance.new("TextButton")
        tombolToggle.Name = "ToggleBlackScreen"
        tombolToggle.Size = UDim2.new(0, 100, 0, 34)
        -- Bawah-tengah, bukan pojok kiri-atas -- area atas sering ketutupan
        -- UI sistem/Roblox di HP dan cloud phone, jadi lebih susah dipencet.
        tombolToggle.Position = UDim2.new(0.5, 0, 1, -44)
        tombolToggle.AnchorPoint = Vector2.new(0.5, 0)
        tombolToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        tombolToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        tombolToggle.Font = Enum.Font.GothamBold
        tombolToggle.TextSize = 16
        tombolToggle.Text = "Hide"
        tombolToggle.ZIndex = 20
        tombolToggle.Parent = gui
        local strokeToggle = Instance.new("UIStroke")
        strokeToggle.Thickness = 1
        strokeToggle.Color = Color3.fromRGB(255, 255, 255)
        strokeToggle.Parent = tombolToggle

        tombolToggle.MouseButton1Click:Connect(function()
            bg.Visible = not bg.Visible
            tombolToggle.Text = bg.Visible and "Hide" or "Show"
        end)

        local tengah = Instance.new("TextLabel")
        tengah.Size = UDim2.new(0.4, 0, 0.2, 0)
        tengah.Position = UDim2.new(0.5, 0, 0.4, 0)
        tengah.AnchorPoint = Vector2.new(0.5, 0.5)
        tengah.BackgroundTransparency = 1
        tengah.Text = "Loading..."
        tengah.TextColor3 = Color3.fromRGB(255, 255, 0)
        tengah.TextScaled = true
        tengah.Font = Enum.Font.GothamBold
        tengah.ZIndex = 10
        tengah.Parent = bg
        local batasTeks = Instance.new("UITextSizeConstraint")
        batasTeks.MaxTextSize = 25
        batasTeks.Parent = tengah
        local strokeTengah = Instance.new("UIStroke")
        strokeTengah.Thickness = 1.5
        strokeTengah.Color = Color3.fromRGB(0, 0, 0)
        strokeTengah.Parent = tengah

        local riwayat = Instance.new("TextLabel")
        riwayat.Size = UDim2.new(0.4, 0, 0.3, 0)
        riwayat.Position = UDim2.new(0.5, 0, 0.5, 0)
        riwayat.AnchorPoint = Vector2.new(0.5, 0)
        riwayat.BackgroundTransparency = 1
        riwayat.Text = ""
        riwayat.TextColor3 = Color3.fromRGB(150, 255, 150)
        riwayat.TextSize = 14
        riwayat.TextXAlignment = Enum.TextXAlignment.Center
        riwayat.TextYAlignment = Enum.TextYAlignment.Top
        riwayat.TextWrapped = true
        riwayat.Font = Enum.Font.GothamBold
        riwayat.ZIndex = 10
        riwayat.Parent = bg
        local strokeRiwayat = Instance.new("UIStroke")
        strokeRiwayat.Thickness = 1.2
        strokeRiwayat.Color = Color3.fromRGB(0, 0, 0)
        strokeRiwayat.Parent = riwayat

        -- Panel gear (kiri) & seed (kanan) di ruang kosong pinggir layar,
        -- persis di posisi dua gambar yang dulu dihapus dari sini.
        local panelGear = Instance.new("TextLabel")
        panelGear.Size = UDim2.new(0.26, 0, 0.5, 0)
        panelGear.Position = UDim2.new(0.03, 0, 0.5, 0)
        panelGear.AnchorPoint = Vector2.new(0, 0.5)
        panelGear.BackgroundTransparency = 1
        panelGear.Text = "⚙️ GEAR"
        panelGear.TextColor3 = Color3.fromRGB(180, 210, 255)
        panelGear.TextSize = 14
        panelGear.TextXAlignment = Enum.TextXAlignment.Left
        panelGear.TextYAlignment = Enum.TextYAlignment.Top
        panelGear.TextWrapped = true
        panelGear.Font = Enum.Font.GothamBold
        panelGear.ZIndex = 10
        panelGear.Parent = bg
        local strokeGear = Instance.new("UIStroke")
        strokeGear.Thickness = 1
        strokeGear.Color = Color3.fromRGB(0, 0, 0)
        strokeGear.Parent = panelGear

        local panelSeed = Instance.new("TextLabel")
        panelSeed.Size = UDim2.new(0.26, 0, 0.5, 0)
        panelSeed.Position = UDim2.new(0.97, 0, 0.5, 0)
        panelSeed.AnchorPoint = Vector2.new(1, 0.5)
        panelSeed.BackgroundTransparency = 1
        panelSeed.Text = "🌱 SEED"
        panelSeed.TextColor3 = Color3.fromRGB(180, 255, 190)
        panelSeed.TextSize = 14
        panelSeed.TextXAlignment = Enum.TextXAlignment.Right
        panelSeed.TextYAlignment = Enum.TextYAlignment.Top
        panelSeed.TextWrapped = true
        panelSeed.Font = Enum.Font.GothamBold
        panelSeed.ZIndex = 10
        panelSeed.Parent = bg
        local strokeSeed = Instance.new("UIStroke")
        strokeSeed.Thickness = 1
        strokeSeed.Color = Color3.fromRGB(0, 0, 0)
        strokeSeed.Parent = panelSeed

        local perf = Instance.new("TextLabel")
        perf.Size = UDim2.new(0.5, 0, 0.05, 0)
        perf.Position = UDim2.new(0.5, 0, 0.02, 0)
        perf.AnchorPoint = Vector2.new(0.5, 0)
        perf.BackgroundTransparency = 1
        perf.Text = "FPS: - | Ping: - ms | Mem: - MB"
        perf.TextColor3 = Color3.fromRGB(200, 200, 200)
        perf.TextSize = 14
        perf.Font = Enum.Font.Code
        perf.ZIndex = 10
        perf.Parent = bg
        local strokePerf = Instance.new("UIStroke")
        strokePerf.Thickness = 1
        strokePerf.Color = Color3.fromRGB(0, 0, 0)
        strokePerf.Parent = perf

        local debug = Instance.new("TextLabel")
        debug.Size = UDim2.new(0.8, 0, 0.05, 0)
        debug.Position = UDim2.new(0.5, 0, 0.08, 0)
        debug.AnchorPoint = Vector2.new(0.5, 0)
        debug.BackgroundTransparency = 1
        debug.TextColor3 = Color3.fromRGB(255, 255, 0)
        debug.TextSize = 13
        debug.Font = Enum.Font.Code
        debug.ZIndex = 10
        debug.Text = "Menunggu kaitun..."
        debug.Parent = bg
        local strokeDebug = Instance.new("UIStroke")
        strokeDebug.Thickness = 1
        strokeDebug.Color = Color3.fromRGB(0, 0, 0)
        strokeDebug.Parent = debug

        -- Ditempel ke CoreGui kalau executor mendukung, supaya tidak ikut hilang
        -- saat karakter respawn.
        local berhasil = pcall(function()
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not berhasil then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        task.spawn(function()
            local Stats = game:GetService("Stats")
            -- Menit terakhir panel gear/seed direfresh -- dibandingkan
            -- terhadap jam sungguhan (os.date), bukan dihitung mundur dari
            -- saat script mulai, supaya jatuh di menit bulat yang sama
            -- persis tiap kali (:02, :07, :12, ... :57).
            local menitRefreshTerakhir = nil
            while gui.Parent do
                local daun = 0
                pcall(function()
                    local ls = LocalPlayer:FindFirstChild("leaderstats")
                    local n = ls and ls:FindFirstChild("Leaves")
                    if n then daun = n.Value end
                end)
                tengah.Text = "👤 " .. LocalPlayer.Name .. "\n🍃 " .. ringkasAngka(daun)

                riwayat.Text = (#_G.FHRiwayat > 0)
                    and ("📜 RIWAYAT:\n" .. table.concat(_G.FHRiwayat, "\n"))
                    or ""

                local ping, fps, mem = "0", "0", "0"
                pcall(function()
                    ping = string.split(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString(), " ")[1] or "0"
                end)
                pcall(function() fps = tostring(math.floor(workspace:GetRealPhysicsFPS())) end)
                pcall(function()
                    mem = string.split(Stats.PerformanceStats.Memory:GetValueString(), " ")[1] or "0"
                end)
                perf.Text = string.format("🎮 FPS: %s  |  📶 Ping: %s ms  |  🧠 Mem: %s MB", fps, ping, mem)

                if _G.FallHarvestDebug then debug.Text = tostring(_G.FallHarvestDebug) end

                -- Bacaan tas lebih berat (menelusuri semua Tool di Backpack)
                -- daripada baris lain di atas -- direfresh tiap 5 menit pas
                -- di menit :02/:07/:12/.../:57, dan hanya SEKALI per menit itu
                -- (loop ini sendiri berdetak tiap 1 detik, jadi tanpa penanda
                -- menitRefreshTerakhir baris ini akan tertembak 60x berturut
                -- selama menit yang sama).
                local menitSekarang = tonumber(os.date("%M"))
                if menitSekarang % 5 == 2 and menitSekarang ~= menitRefreshTerakhir then
                    menitRefreshTerakhir = menitSekarang
                    local seedMap, gearMap = bacaInventoryRingkas()
                    panelGear.Text = "⚙️ GEAR\n" .. formatInventoryHUD(gearMap, "⚙️")
                    panelSeed.Text = formatInventoryHUD(seedMap, "🌱") .. "\n🌱 SEED"
                end

                task.wait(1)
            end
        end)
    end)

    if not ok then warn("[FH] Gagal memasang black screen") end
end

-- ==========================================================
-- ANTI-AFK
-- ==========================================================
local function pasangAntiAFK()
    local vu = game:GetService("VirtualUser")
    local vim = game:GetService("VirtualInputManager")

    -- Lapis 1: balasan langsung saat Roblox menandai idle.
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end)

    -- Lapis 2: gerakan nyata berkala. Klik saja kadang tidak cukup pada sesi
    -- panjang; lompatan menghasilkan input fisik yang jelas.
    --
    -- Disalin sebelum loop mulai supaya re-run di sesi yang sama (loadstring
    -- dijalankan ulang tanpa rejoin) tidak meninggalkan loop lompat lama tetap
    -- jalan berdampingan dengan yang baru.
    local instanceSayaLokal = _G.FHInstance
    task.spawn(function()
        while _G.FHInstance == instanceSayaLokal do
            task.wait(math.random(150, 240))
            if _G.FHInstance ~= instanceSayaLokal then break end
            pcall(function()
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            pcall(function()
                local hum = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end)
        end
    end)
end

-- ==========================================================
-- FPS BOOST
-- ==========================================================
-- Versi asli menghapus seluruh Workspace.Gardens. Di sini kebun sendiri tetap
-- dilindungi meski tidak lagi dipakai untuk tanam/panen manual -- sekadar
-- jaga-jaga (murah, dan menghindari kebiasaan lama yang pernah menghapus
-- kebun sungguhan). Yang dibuang hanya kebun MILIK ORANG LAIN -- justru
-- penyumbang beban terbesar (Plot7 saja terhitung 178 tanaman).
local function bersihkanKebunOrang(tunggu)
    if not Config.FpsBoost then return end

    local plotku = plotSaya()

    -- Kebun kita sendiri pun belum tentu sudah termuat saat siklus pertama.
    -- Penantian ini hanya untuk pemanggilan pertama; pemanggilan berkala tidak
    -- boleh memblokir siklus selama 20 detik.
    if not plotku and tunggu then
        status("[FPS] Menunggu kebun sendiri termuat...")
        local batas = tick() + 20
        while tick() < batas and not plotku do
            task.wait(1)
            plotku = plotSaya()
        end
    end

    -- GAGAL-TERTUTUP. Ini pernah menghancurkan kebun sungguhan.
    --
    -- Versi lama langsung menghapus tiap kebun yang `g ~= plotku`. Saat plotSaya()
    -- mengembalikan nil, SETIAP kebun tidak sama dengan nil -- jadi semuanya
    -- dihapus, termasuk milik sendiri. Gagal mengenali kebun sendiri TIDAK
    -- BOLEH berarti "tidak ada yang perlu dilindungi". Artinya: jangan hapus
    -- apa pun.
    if not plotku then
        if tunggu then
            status("[FPS] Kebun sendiri tidak terdeteksi — penghapusan DILEWATI demi keamanan")
        end
        return 0
    end

    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return 0 end

    local dibuang = 0
    for _, g in ipairs(gardens:GetChildren()) do
        if g ~= plotku then
            pcall(function() g:Destroy() end)
            dibuang = dibuang + 1
        end
    end
    if dibuang > 0 then
        status(string.format("[FPS] %d kebun orang lain dihapus", dibuang))
    end
    return dibuang
end

-- Menghapus semua tanaman (dan buah yang sedang tumbuh di atasnya, karena
-- itu menempel sebagai bagian dari model tanaman) di kebun SENDIRI.
--
-- Kebun orang lain sudah lenyap SELURUHNYA lewat bersihkanKebunOrang(), jadi
-- yang tersisa di seluruh workspace cuma model tanaman milik sendiri. Aman
-- dihapus karena script ini tidak lagi menanam/memanen/mencabut sama sekali
-- -- murni Destroy() sisi klien, tidak menembak remote apa pun, jadi tidak
-- mengubah apa pun yang tersimpan di server maupun memicu anticheat.
local function bersihkanFruitPlantSendiri()
    if not Config.FpsBoost then return 0 end

    local plotku = plotSaya()
    if not plotku then return 0 end

    local plants = plotku:FindFirstChild("Plants")
    if not plants then return 0 end

    local dihapus = 0
    for _, tanaman in ipairs(plants:GetChildren()) do
        pcall(function() tanaman:Destroy() end)
        dihapus = dihapus + 1
    end
    if dihapus > 0 then
        status(string.format("[FPS] %d tanaman/buah di kebun sendiri dihapus", dihapus))
    end
    return dihapus
end

-- Satu tempat untuk memutuskan "boleh disentuh atau tidak".
-- Dipakai sapuan awal MAUPUN hook DescendantAdded, supaya keduanya tidak bisa
-- berbeda pendapat.
local plotCache = nil
local function plotSayaCepat()
    if plotCache and plotCache.Parent then return plotCache end
    plotCache = plotSaya()
    return plotCache
end

local function bolehDibrutalkan(d)
    if not d or not d.Parent then return false end

    local char = LocalPlayer.Character
    if char and d:IsDescendantOf(char) then return false end

    -- Kebun sendiri dilindungi UTUH -- murni jaga-jaga terhadap kebiasaan lama
    -- yang pernah menghapus kebun sungguhan, bukan karena masih dipakai untuk
    -- tanam/panen manual.
    local plotku = plotSayaCepat()
    if plotku and d:IsDescendantOf(plotku) then return false end

    if d == workspace.Terrain then return false end

    -- NPC WAJIB utuh: Sam/Gilbert (seed), Steven (jual) dicari lewat
    -- HumanoidRootPart -- di sini itu tidak boleh dirusak, karena kita benar-
    -- benar memakai NPC untuk beli dan jual.
    local kini, dalam = d, 0
    while kini and kini ~= workspace and dalam < 5 do
        if kini:FindFirstChildWhichIsA("Humanoid") then return false end
        local n = string.lower(kini.Name)
        if n == "npcs" or n == "npc" then return false end
        kini = kini.Parent
        dalam = dalam + 1
    end

    return true
end

local function brutalkan(d)
    if not bolehDibrutalkan(d) then return false end

    local ok = pcall(function()
        if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
           or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
           or d:IsA("Light") or d:IsA("PostEffect")
           or d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceAppearance")
           or d:IsA("PVAdornment") or d:IsA("HandleAdornment")
           or d:IsA("SurfaceGui") or d:IsA("BillboardGui")
           or d:IsA("KeyframeSequence") then
            d:Destroy()
            return
        end

        if d:IsA("Sound") then
            -- Volume 0, bukan Destroy: beberapa game menunggu Sound.Ended sebagai
            -- bagian alur, dan menghapusnya menggantung alur itu.
            d.Volume = 0
            return
        end

        if d:IsA("BasePart") then
            d.Material = Enum.Material.SmoothPlastic
            d.Reflectance = 0
            d.CastShadow = false
            d.Anchored = true
            -- CanTouch SENGAJA TIDAK disentuh -- mematikannya pernah membuat
            -- shovel/hit-detection ditolak server sampai pemain rejoin.
        end
    end)
    return ok
end

-- Wadah lingkungan yang murni hiasan. Daftar ini DIVERIFIKASI dari isi workspace
-- Fall Harvest, bukan disalin mentah dari script lain.
local WADAH_HIASAN = {
    "Grass", "Trees", "Decorations",
    "BirdVisuals", "Birds", "BlizzardBeams", "LightningEffects",
    "RainDrops", "RainSplashes", "StormRainDrops", "StormSplashes",
    "GnomeVisuals", "Gnomes", "GrapplingHookVisuals", "PottedPlantVisuals",
    "Presents", "Dance", "Weather", "Clouds", "Rain", "PopVFXModel",
}

local function nukeLingkungan()
    local dibuang = 0
    -- GetChildren() ditelusuri, bukan FindFirstChild, karena ada nama yang
    -- MUNCUL BERKALI-KALI (terhitung 12 "PopVFXModel" sekaligus).
    for _, c in ipairs(workspace:GetChildren()) do
        for _, nama in ipairs(WADAH_HIASAN) do
            if c.Name == nama then
                pcall(function() c:Destroy() end)
                dibuang = dibuang + 1
                break
            end
        end
    end

    pcall(function()
        local T = workspace.Terrain
        T.WaterWaveSize = 0
        T.WaterWaveSpeed = 0
        T.WaterReflectance = 0
        T.WaterTransparency = 1
    end)

    return dibuang
end

local hookTerpasang = false

local function pasangHookBrutal()
    if hookTerpasang then return end
    hookTerpasang = true

    -- Inilah bagian yang membuat FPS BERTAHAN, bukan cuma naik sesaat: game
    -- terus memunculkan buah, VFX, dan efek cuaca baru.
    workspace.DescendantAdded:Connect(function(d)
        if not Config.FpsBoost then return end

        -- Saringan kelas didahulukan, dan sengaja memakai perbandingan string
        -- biasa -- bukan :IsA() -- karena ini jalur terpanas di seluruh script.
        local k = d.ClassName
        if k == "Folder" or k == "Model" or k == "Configuration"
           or k == "Script" or k == "LocalScript" or k == "ModuleScript" then
            return
        end

        task.defer(brutalkan, d)
    end)
end

local hookGardenTerpasang = false
local jadwalBersihGardenAktif = false

-- Kebun orang lain dimuat bertahap begitu pemain baru masuk server -- tanpa
-- ini, kebun barunya cuma dihapus di sapuan periodik berikutnya (bisa
-- puluhan detik). Hook ini bereaksi begitu Model kebun baru MUNCUL di
-- workspace.Gardens, jadi jedanya jauh lebih pendek.
local function pasangHookGardenBaru()
    if hookGardenTerpasang then return end
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return end
    hookGardenTerpasang = true

    gardens.ChildAdded:Connect(function()
        if not Config.FpsBoost then return end
        -- Debounce: server sering memuat BEBERAPA kebun sekaligus (mis. saat
        -- server baru terisi banyak pemain dalam hitungan detik). Tanpa ini,
        -- tiap kebun baru menjadwalkan sapuan penuhnya sendiri dan semuanya
        -- menumpuk hampir bersamaan -- satu sapuan yang cukup diulang berkali-
        -- kali secara sia-sia.
        if jadwalBersihGardenAktif then return end
        jadwalBersihGardenAktif = true

        task.defer(function()
            -- Beri sedikit waktu supaya Model-nya (dan atribut pemiliknya)
            -- selesai termuat -- deteksi terlalu dini bisa salah kira kebun
            -- baru ini kebun sendiri padahal atributnya belum sempat terpasang.
            task.wait(1)
            bersihkanKebunOrang(false)
            jadwalBersihGardenAktif = false
        end)
    end)
end

local function applyFpsBoost()
    if not Config.FpsBoost then return end
    status("[FPS] Membersihkan dekorasi berat...")

    bersihkanKebunOrang(true)
    bersihkanFruitPlantSendiri()

    local nWadah = nukeLingkungan()

    pcall(function()
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        -- Teknologi rendering termurah yang Roblox punya -- tidak ada kalkulasi
        -- shadow map/voxel lighting sama sekali. Ini pengaruhnya paling besar
        -- ke FPS dari semua pengaturan Lighting di sini.
        Lighting.Technology = Enum.Technology.Compatibility
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("BloomEffect") or c:IsA("BlurEffect") or c:IsA("ColorCorrectionEffect")
               or c:IsA("SunRaysEffect") or c:IsA("DepthOfFieldEffect")
               or c:IsA("Atmosphere") or c:IsA("Sky") then
                c:Destroy()
            end
        end
    end)

    -- FOV sempit = lebih sedikit objek yang masuk frustum kamera untuk
    -- dirender. Dulu ini nempel di pasangBlackScreen(), padahal FOV kecil
    -- adalah penghematan render, bukan urusan layar hitam -- sekarang berlaku
    -- kapan pun FpsBoost aktif, terlepas dari BlackScreen nyala atau tidak.
    pcall(function() workspace.CurrentCamera.FieldOfView = 30 end)

    local hitung, kena = 0, 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if brutalkan(d) then kena = kena + 1 end
        hitung = hitung + 1
        if hitung % 500 == 0 then task.wait() end
    end

    pcall(function()
        local n = 0
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
               or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                pcall(function() d.Enabled = false end)
                n = n + 1
            elseif d:IsA("Sound") then
                pcall(function() d.Volume = 0 end)
                n = n + 1
            end
            if n % 500 == 0 then task.wait() end
        end
        status(string.format("[FPS] %d wadah hiasan, %d objek dibrutalkan, %d efek/suara dimatikan",
            nWadah, kena, n))
    end)

    if Config.BatasFps and Config.BatasFps > 0 and typeof(setfpscap) == "function" then
        pcall(setfpscap, Config.BatasFps)
        status(string.format("[FPS] Batas frame %d", Config.BatasFps))
    end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    -- Geometri MeshPart termurah yang tersedia -- lebih sedikit vertex untuk
    -- di-render per model.
    pcall(function()
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.DetailLevel0
    end)

    -- Audio dimatikan sepenuhnya -- tidak ada yang mendengarkan (berjalan di
    -- background/cloud phone), jadi decoding suara murni pemborosan CPU.
    pcall(function()
        UserSettings():GetService("UserGameSettings").MasterVolume = 0
    end)

    -- Pemulihan CanTouch di kebun sendiri, kalau versi sebelumnya sempat
    -- mematikannya secara tidak sengaja.
    pcall(function()
        local p = plotSaya()
        if not p then return end
        local pulih = 0
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("BasePart") and d.CanTouch == false then
                d.CanTouch = true
                pulih = pulih + 1
            end
        end
        if pulih > 0 then
            status(string.format("[FPS] %d part kebun dipulihkan CanTouch-nya", pulih))
        end
    end)

    pasangHookBrutal()
    pasangHookGardenBaru()

    status("[FPS] Selesai")
end

-- ==========================================================
-- SHOP
-- ==========================================================
-- Struktur UI-nya: Frame.NormalShop berisi kartu bernama item, harga di
-- Cost_Text ("1c", "2.5Kc", "NO STOCK").
local function parseHarga(teks)
    if not teks then return 0 end
    local c = string.upper(teks)
    c = c:gsub("%s+", ""):gsub("\194\162", ""):gsub("\238\128\130", "")
    if c:match("^X%d+") then return 0 end
    local num, suf = c:match("([%d%.%,]+)([MBK]?)")
    if not num then return 0 end
    local a = tonumber((num:gsub(",", ""))) or 0
    if suf == "K" then a = a * 1e3 elseif suf == "M" then a = a * 1e6 elseif suf == "B" then a = a * 1e9 end
    return a
end

-- Struktur UI SeedShop dan GearShop sama persis, cuma nama ScreenGui-nya
-- berbeda -- satu fungsi generik dipakai untuk keduanya.
local function bacaStokUI(namaGui)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild(namaGui)
    local frame = shop and shop:FindFirstChild("Frame")
    local wadah = frame and (frame:FindFirstChild("NormalShop") or frame:FindFirstChild("ScrollingFrame"))
    if not wadah then return {} end

    local hasil = {}
    for _, kartu in ipairs(wadah:GetChildren()) do
        if kartu:IsA("Frame") and kartu.Name ~= "ItemTemplate" and kartu.Name ~= "Padding" then
            local cost = kartu:FindFirstChild("Cost_Text", true)
            local harga = cost and parseHarga(cost.Text) or 0
            if harga > 0 then
                hasil[#hasil + 1] = { nama = kartu.Name, harga = harga }
            end
        end
    end
    -- Termurah dulu, sesuai permintaan: beli dari termurah sampai termahal.
    table.sort(hasil, function(a, b) return a.harga < b.harga end)
    return hasil
end

local function stokShop() return bacaStokUI("SeedShop") end
local function stokGear() return bacaStokUI("GearShop") end

-- Saring daftar shop sesuai whitelist config ({ ["Nama Item"] = true/false }).
-- whitelist == nil berarti TIDAK ada penyaringan -- beli semua yang ada di rak.
-- Kalau diisi, hanya nama dengan nilai persis `true` yang lolos.
local function saringWhitelist(daftar, whitelist)
    if not whitelist then return daftar end
    local hasil = {}
    for _, s in ipairs(daftar) do
        if whitelist[s.nama] == true then hasil[#hasil + 1] = s end
    end
    return hasil
end

-- Posisi NPC. Perannya dipastikan dari Script di dalam ProximityPrompt masing-
-- masing: Sam & Gilbert membuka SeedShop, George membuka GearShop, Steven jual.
local NPC_PERAN = { seed = { "Sam", "Gilbert" }, gear = { "George" }, jual = { "Steven" } }

local function posisiNPC(peran)
    local npcs = workspace:FindFirstChild("NPCS")
    if not npcs then return nil, nil end
    for _, nama in ipairs(NPC_PERAN[peran] or {}) do
        local n = npcs:FindFirstChild(nama)
        local root = n and (n:FindFirstChild("HumanoidRootPart") or n.PrimaryPart)
        if root then return root.Position, nama end
    end
    return nil, nil
end

local function leaves()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local n = ls and ls:FindFirstChild("Leaves")
    return n and n.Value or 0
end

-- ==========================================================
-- AKSI: BELI & JUAL
-- ==========================================================
-- Menghitung apa saja yang dibeli sejak checkpoint 5-menit terakhir --
-- dibaca dan dikosongkan oleh pasangCheckpointLeaves(). Tabel yang sama
-- (bukan disalin) sengaja dipakai kedua fungsi supaya keduanya tidak bisa
-- berbeda pendapat soal apa yang sudah "dilaporkan".
local pembelianJendela = {}

-- Dipakai bersama oleh beli seed dan beli gear -- satu-satunya beda adalah
-- peran NPC yang didekati, remote yang ditembak, dan nama GUI shop-nya.
local function beliDari(daftar, peran, tembak, labelNPC, namaGuiShop)
    -- BEDA dengan jual: membeli WAJIB dari dekat.
    --
    -- Secara teknis PurchaseSeed/PurchaseGear tetap diterima dari jarak jauh,
    -- tapi anticheat menandainya dan ban menyusul belakangan -- jadi "berhasil"
    -- di sini justru menyesatkan. Karena itu mendekat bukan opsi yang bisa
    -- dimatikan lewat config, dan kalau gagal mencapai NPC, pembelian
    -- DIBATALKAN seluruhnya.
    local pos, nama = posisiNPC(peran)
    if not pos then
        status("[BATAL] NPC " .. labelNPC .. " tidak ketemu")
        return 0
    end
    if not pergiKe(pos) then
        status("[BATAL] Gagal mencapai " .. tostring(nama) .. " — beli dilewati demi keamanan")
        return 0
    end
    status("[BELI] Di dekat " .. tostring(nama) .. " (jarak " .. math.floor(jarakKe(pos)) .. ")")

    local dibeli = 0
    for _, s in ipairs(daftar) do
        if dibeli >= Config.MaxBeliPerSiklus then break end

        -- Habiskan item INI dulu -- tembak berulang sampai stoknya hilang dari
        -- rak atau Leaves tidak cukup lagi -- baru pindah ke item berikutnya.
        -- Sebelumnya cuma satu tembakan per item lalu langsung lompat ke seed
        -- lain, jadi tiap jenis cuma kebagian 1 biji walau stoknya masih ada.
        local harga = s.harga
        local dibeliItemIni = 0
        -- Jaring pengaman: kalau tembakan terus gagal (error remote sesaat)
        -- padahal stok dan Leaves masih cukup, tidak ada apa pun di atas yang
        -- pernah menghentikan loop-nya -- ini satu-satunya yang membuatnya
        -- berhenti alih-alih menembak sia-sia selamanya.
        local gagalBerturut = 0

        while dibeli < Config.MaxBeliPerSiklus do
            -- Jarak diperiksa ulang tiap tembakan: karakter bisa terdorong
            -- menjauh di tengah pembelian, dan satu fire dari jauh sudah
            -- cukup untuk ditandai.
            if jarakKe(pos) > Config.JarakAman * 2 then
                if not pergiKe(pos) then
                    status("[BATAL] Terlempar dari NPC, sisa pembelian dihentikan")
                    return dibeli
                end
            end
            if leaves() < harga then break end

            local ok = pcall(function() tembak(s.nama) end)
            if ok then
                dibeli = dibeli + 1
                dibeliItemIni = dibeliItemIni + 1
                pembelianJendela[s.nama] = (pembelianJendela[s.nama] or 0) + 1
                gagalBerturut = 0
            else
                gagalBerturut = gagalBerturut + 1
                if gagalBerturut >= 3 then
                    status("[BATAL] " .. s.nama .. " gagal ditembak 3x berturut-turut — dilewati")
                    break
                end
            end
            task.wait(Config.JedaAksi)

            -- Berhenti begitu item ini hilang dari rak (stok habis) --
            -- dicek ulang dari UI yang sama persis dipakai stokShop()/
            -- stokGear(), bukan ditebak dari berapa kali sudah menembak.
            local stokTerkini = bacaStokUI(namaGuiShop)
            local masihAda = false
            for _, cek in ipairs(stokTerkini) do
                if cek.nama == s.nama then
                    masihAda = true
                    harga = cek.harga
                    break
                end
            end
            if not masihAda then break end
        end

        if dibeliItemIni > 0 then
            status(string.format("[BELI] %s x%d (%d Leaves, sisa %d)",
                s.nama, dibeliItemIni, harga, leaves()))
            catatRiwayat(string.format("🛒 %s x%d (%d)", s.nama, dibeliItemIni, harga))
        end
    end
    return dibeli
end

local function beli(daftar)
    return beliDari(daftar, "seed",
        function(nama) Networking.SeedShop.PurchaseSeed:Fire(nama) end,
        "penjual seed", "SeedShop")
end

local function beliGear(daftar)
    return beliDari(daftar, "gear",
        function(nama) Networking.GearShop.PurchaseGear:Fire(nama) end,
        "penjual gear", "GearShop")
end

local function jual()
    -- Terbukti di lapangan: SellAll diterima dari jarak jauh, jadi tidak perlu
    -- terbang ke Steven sama sekali. Pencarian NPC hanya dilakukan kalau kamu
    -- memaksa mendekat lewat config.
    if Config.DekatSaatJual then
        local pos, nama = posisiNPC("jual")
        if pos and not pergiKe(pos) then
            status("[LEWAT] Gagal mencapai " .. tostring(nama))
            return false
        end
    end

    -- SellAll tidak mengembalikan berapa Leaves yang didapat -- dibaca lewat
    -- selisih leaderstats sebelum/sesudah, bukan dari hasil remote.
    local sebelum = leaves()

    -- Daily Deal DULU, sebelum SellAll. Urutan ini disengaja: begitu SellAll
    -- jalan, buah yang sebenarnya termasuk daily deal sudah keburu terjual
    -- lewat jalur biasa dan bonusnya hilang.
    if Config.DailyDeal then
        pcall(function() Networking.NPCS.UseDailyDealAll:Fire() end)
        task.wait(Config.JedaAksi)
    end

    -- Staging wajib. Tanpa PreviewSellAll lebih dulu, SellAll ditolak diam-diam.
    pcall(function() Networking.NPCS.PreviewSellAll:Fire() end)
    task.wait(Config.JedaAksi)
    pcall(function() Networking.NPCS.SellAll:Fire() end)

    -- Leaves butuh waktu untuk direplikasi server -> klien; tanpa jeda ini
    -- selisihnya sering masih terbaca 0 padahal penjualannya sendiri berhasil.
    task.wait(1)
    local sesudah = leaves()
    local untung = sesudah - sebelum

    status(string.format("[JUAL] SellAll dikirim (Leaves: %d)", sesudah))
    -- Riwayat hanya dicatat kalau BENAR-BENAR ada buah yang laku (Leaves naik).
    -- SellAll ditembak setiap siklus terlepas ada buah atau tidak, dan kalau
    -- baris "tidak jual apa-apa" ikut masuk riwayat, 8 barisnya cepat penuh
    -- oleh entri kosong dan menenggelamkan riwayat beli/jual yang sungguhan.
    if untung > 0 then
        catatRiwayat(string.format("💰 Jual +%s (Leaves: %s)", ringkasAngka(untung), ringkasAngka(sesudah)))
    end
    return true
end

-- Ringkasan pembelian sejak checkpoint terakhir, urut nama.
local function ringkasPembelian(map)
    local bagian = {}
    for nama, jumlah in pairs(map) do
        bagian[#bagian + 1] = string.format("%s x%d", nama, jumlah)
    end
    if #bagian == 0 then return "tidak ada pembelian baru" end
    table.sort(bagian)
    return table.concat(bagian, ", ")
end

-- Checkpoint 5 menit: satu baris riwayat berisi apa saja yang dibeli sejak
-- checkpoint sebelumnya, plus Leaves sekarang dan selisihnya. Ini terpisah
-- dari baris beli/jual yang sudah live per-transaksi -- checkpoint ini untuk
-- melihat ringkasan tanpa harus menonton terus, terutama karena stok shop
-- sendiri hanya berubah tiap ~5 menit (restock).
local function pasangCheckpointLeaves()
    if not Config.BlackScreen then return end
    -- _G.FHInstance sudah bertambah sebelum fungsi ini dipanggil (lihat LOOP
    -- UTAMA), jadi nilai yang disalin di sini adalah nomor instance SAAT INI.
    -- Tanpa penjagaan ini, re-run di sesi yang sama (loadstring dijalankan
    -- ulang tanpa rejoin) meninggalkan checkpoint lama tetap jalan selamanya,
    -- dan riwayat kebanjiran baris checkpoint ganda tiap 5 menit.
    local instanceSayaLokal = _G.FHInstance
    task.spawn(function()
        local awal = leaves()
        while _G.FHInstance == instanceSayaLokal do
            task.wait(300)
            if _G.FHInstance ~= instanceSayaLokal then break end

            local sekarang = leaves()
            local delta = sekarang - awal
            local deltaTeks = (delta >= 0 and "+" or "") .. ringkasAngka(delta)

            catatRiwayat(string.format("⏱ %s | %s | 🍃 %s (%s)",
                os.date("%H:%M"), ringkasPembelian(pembelianJendela),
                ringkasAngka(sekarang), deltaTeks))

            -- Dikosongkan di TEMPAT, bukan diganti tabel baru -- beliDari()
            -- memegang acuan ke tabel yang sama persis.
            for k in pairs(pembelianJendela) do pembelianJendela[k] = nil end
            awal = sekarang
        end
    end)
end

-- ==========================================================
-- LOOP UTAMA
-- ==========================================================
_G.FHInstance = (_G.FHInstance or 0) + 1
local instanceSaya = _G.FHInstance

status(string.format("Aktif (#%d) — menunggu dunia siap...", instanceSaya))
tungguGameSiap()

status(string.format("Aktif (#%d) — mode ringkas: beli + jual", instanceSaya))

pasangBlackScreen()
pasangCheckpointLeaves()
if Config.AntiAFK then pasangAntiAFK() end

task.spawn(function()
    local putaranSiklus = 0
    while instanceSaya == _G.FHInstance do
        putaranSiklus = putaranSiklus + 1

        -- Seluruh isi siklus dibungkus pcall: satu error sesaat (karakter
        -- respawn, kebun sedang dimuat ulang) tidak boleh menghentikan bot
        -- permanen tanpa pesan.
        local okSiklus, errSiklus = pcall(function()
            local fase = {}

            -- Sapuan berat cukup SEKALI di siklus pertama; kebun orang lain
            -- dimuat bertahap, jadi dibersihkan lagi secara berkala.
            if putaranSiklus == 1 then
                fase[#fase + 1] = { "fps-boost", applyFpsBoost }
            elseif Config.SiklusBersihKebun > 0
                   and putaranSiklus % Config.SiklusBersihKebun == 0 then
                fase[#fase + 1] = { "bersih-kebun", function()
                    bersihkanKebunOrang(false)
                    bersihkanFruitPlantSendiri()
                end }
            end

            -- Jual dulu supaya Leaves-nya bisa langsung dipakai belanja di
            -- fase berikutnya pada siklus yang sama.
            if Config.AutoJual then fase[#fase + 1] = { "jual", jual } end

            if Config.AutoBeli then
                fase[#fase + 1] = { "beli", function()
                    local stok = saringWhitelist(stokShop(), Config.SeedWhitelist)
                    if #stok > 0 then beli(stok) end
                end }
            end

            if Config.AutoBeliGear then
                fase[#fase + 1] = { "beli-gear", function()
                    local stok = saringWhitelist(stokGear(), Config.GearWhitelist)
                    if #stok > 0 then beliGear(stok) end
                end }
            end

            for _, f in ipairs(fase) do
                if instanceSaya ~= _G.FHInstance then break end
                local ok, err = pcall(f[2])
                if not ok then status("[ERROR] fase " .. f[1] .. ": " .. tostring(err)) end
                task.wait(Config.JedaAksi)
            end
        end)

        if not okSiklus then
            status("[ERROR] siklus " .. putaranSiklus .. ": " .. tostring(errSiklus))
            task.wait(3)
        end

        task.wait(Config.JedaSiklus)
    end
    print("[FH] Instance #" .. instanceSaya .. " berhenti.")
end)

--[[
    AUTO SHOVEL -- kerangka SUDAH lengkap, SATU fungsi masih menunggu data.

    Skrip ini TERPISAH dari akk.lua. Tujuannya: mencabut (shovel) SEMUA
    tanaman di kebun SENDIRI sekali jalan, sambil menampilkan hitungan
    "akan dicabut" dan "berhasil dicabut" di layar.

    YANG SUDAH JADI:
      - UI counter kecil di pojok (target vs berhasil, update live).
      - Deteksi kebun sendiri (plotSaya) -- sama seperti akk.lua, 3 lapis
        cadangan, gagal-tertutup (nil = tidak menyentuh apa pun).
      - Loop per-tanaman dengan jeda antar aksi.

    YANG BELUM: cabutSatuTanaman() di bawah masih KOSONG (cuma warn(), tidak
    menembak remote apa pun). Itu disengaja -- shovel di Fall Harvest
    kelihatannya pakai touch/hit-detection lewat tool, bukan RemoteEvent
    sederhana kayak PurchaseSeed/SellAll, dan menebak remote/tool yang salah
    bisa diam-diam gagal atau malah kena tandai anticheat. Jalankan
    shovel_spy.lua dulu, cabut satu tanaman manual, lalu kirim hasil [SPY]
    -- itu dipakai buat mengisi cabutSatuTanaman() supaya beneran nyata,
    bukan tebakan. Bagian lain skrip ini TIDAK perlu diubah lagi setelah itu.
]]

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Config = {
    -- Jeda antar tanaman -- jangan 0, biar tidak terlihat seperti spam
    -- remote beruntun kalau cabutSatuTanaman() nanti sudah diisi.
    JedaAksi = 0.5,
}

-- ==========================================================
-- PLOT (disalin dari akk.lua -- deteksi kebun sendiri, gagal-tertutup)
-- ==========================================================
local function plotSaya()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end

    for _, g in ipairs(gardens:GetChildren()) do
        for _, kunci in ipairs({ "OwnerUserId", "UserId", "Owner", "OwnerId", "PlayerUserId" }) do
            if tostring(g:GetAttribute(kunci)) == tostring(LocalPlayer.UserId) then return g end
        end
    end

    local uid = tostring(LocalPlayer.UserId)
    for _, g in ipairs(gardens:GetChildren()) do
        local plants = g:FindFirstChild("Plants")
        if plants then
            for _, t in ipairs(plants:GetChildren()) do
                if string.match(t.Name, "^(%d+)_") == uid then return g end
            end
        end
    end

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
-- UI COUNTER
-- ==========================================================
local target, berhasil = 0, 0
local labelTarget, labelBerhasil

local function pasangUI()
    local tempatGui = {}
    local okGethui, hui = pcall(function() return gethui and gethui() end)
    if okGethui and hui then table.insert(tempatGui, hui) end
    table.insert(tempatGui, game:GetService("CoreGui"))

    for _, wadah in ipairs(tempatGui) do
        local lama = wadah:FindFirstChild("AutoShovelUI")
        if lama then pcall(function() lama:Destroy() end) end
    end

    local ok = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "AutoShovelUI"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true

        local panel = Instance.new("Frame")
        panel.Size = UDim2.new(0, 220, 0, 70)
        panel.Position = UDim2.new(0, 10, 0, 10)
        panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        panel.BackgroundTransparency = 0.25
        panel.BorderSizePixel = 0
        panel.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = panel

        labelTarget = Instance.new("TextLabel")
        labelTarget.Size = UDim2.new(1, -16, 0, 28)
        labelTarget.Position = UDim2.new(0, 8, 0, 6)
        labelTarget.BackgroundTransparency = 1
        labelTarget.Text = "Akan dicabut: 0"
        labelTarget.TextColor3 = Color3.fromRGB(255, 255, 255)
        labelTarget.TextXAlignment = Enum.TextXAlignment.Left
        labelTarget.Font = Enum.Font.GothamBold
        labelTarget.TextSize = 16
        labelTarget.Parent = panel

        labelBerhasil = Instance.new("TextLabel")
        labelBerhasil.Size = UDim2.new(1, -16, 0, 28)
        labelBerhasil.Position = UDim2.new(0, 8, 0, 34)
        labelBerhasil.BackgroundTransparency = 1
        labelBerhasil.Text = "Berhasil dicabut: 0"
        labelBerhasil.TextColor3 = Color3.fromRGB(120, 255, 140)
        labelBerhasil.TextXAlignment = Enum.TextXAlignment.Left
        labelBerhasil.Font = Enum.Font.GothamBold
        labelBerhasil.TextSize = 16
        labelBerhasil.Parent = panel

        local berhasilParent = pcall(function()
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not berhasilParent then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end)
    if not ok then warn("[SHOVEL] Gagal memasang UI counter") end
end

local function perbaruiUI()
    if labelTarget then labelTarget.Text = "Akan dicabut: " .. target end
    if labelBerhasil then labelBerhasil.Text = "Berhasil dicabut: " .. berhasil end
end

-- ==========================================================
-- AKSI CABUT -- BELUM DIISI, lihat catatan panjang di atas berkas ini.
-- ==========================================================
-- KOSONG DISENGAJA: tidak menembak remote apa pun sampai signature asli
-- didapat dari shovel_spy.lua. Kembalikan false = tidak dihitung "berhasil".
local function cabutSatuTanaman(tanaman)
    warn("[SHOVEL] Aksi cabut belum diisi remote asli -- " ..
        tanaman:GetFullName() .. " DILEWATI (tidak dicabut sungguhan).")
    return false
end

-- ==========================================================
-- JALANKAN
-- ==========================================================
pasangUI()

local plot = plotSaya()
if not plot then
    warn("[SHOVEL] Kebun sendiri tidak terdeteksi -- berhenti demi keamanan, tidak ada yang disentuh.")
    return
end

local plants = plot:FindFirstChild("Plants")
if not plants then
    warn("[SHOVEL] Kebun sendiri tidak punya folder Plants -- tidak ada yang dicabut.")
    return
end

local daftar = plants:GetChildren()
target = #daftar
berhasil = 0
perbaruiUI()
print(string.format("[SHOVEL] %d tanaman terdeteksi di kebun sendiri, mulai mencabut...", target))

for _, tanaman in ipairs(daftar) do
    if tanaman.Parent then
        local ok = cabutSatuTanaman(tanaman)
        if ok then
            berhasil = berhasil + 1
            perbaruiUI()
        end
    end
    task.wait(Config.JedaAksi)
end

print(string.format("[SHOVEL] Selesai: %d/%d berhasil dicabut", berhasil, target))

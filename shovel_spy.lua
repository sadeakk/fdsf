--[[
    SHOVEL SPY -- alat sekali pakai untuk MENANGKAP remote/tool asli yang
    dipakai game saat mencabut (shovel) tanaman.

    BUKAN auto-shovel. Ini cuma mendengarkan komunikasi klien->server yang
    SUDAH terjadi -- tidak menembak apa pun sendiri, tidak menekan tombol
    apa pun untukmu.

    CARA PAKAI:
      1. Jalankan skrip ini SENDIRIAN (bukan bareng akk.lua) lewat Delta Lite.
      2. Di dalam game, cabut SATU tanaman dengan cara manual seperti biasa
         (equip Shovel, klik/tekan pada tanaman, dsb).
      3. Lihat output di console executor -- akan muncul baris [SPY] berisi
         nama remote lengkap dan argumen yang dikirim persis saat itu.
      4. Salin baris [SPY] itu (atau baca shovel_log.txt kalau writefile
         tersedia) dan kirim ke saya. Itu yang akan dipakai membangun
         auto_shovel.lua yang sungguhan -- bukan tebakan.

    Kalau setelah mencabut TIDAK ADA baris [SPY] yang muncul sama sekali,
    berarti aksinya tidak lewat FireServer/InvokeServer biasa (mis. lewat
    UnreliableRemoteEvent, atau server mendeteksi lewat Touched tanpa remote
    eksplisit dari klien sama sekali) -- kabari saya juga kalau begitu,
    karena itu artinya pendekatannya harus beda.
]]

if typeof(hookmetamethod) ~= "function" then
    warn("[SPY] Executor ini tidak punya hookmetamethod -- spy tidak bisa jalan di sini.")
    return
end

local tulisLog = typeof(writefile) == "function"
if tulisLog then
    pcall(function() writefile("shovel_log.txt", "") end)
end

local function catat(baris)
    print(baris)
    if tulisLog then
        pcall(function()
            local lama = ""
            pcall(function() lama = readfile("shovel_log.txt") end)
            writefile("shovel_log.txt", lama .. baris .. "\n")
        end)
    end
end

local function formatArg(a)
    local t = typeof(a)
    if t == "Instance" then
        local ok, full = pcall(function() return a:GetFullName() end)
        return "Instance<" .. (ok and full or a.ClassName) .. ">"
    elseif t == "string" then
        return string.format("%q", a)
    elseif t == "table" then
        return "table"
    else
        return tostring(a)
    end
end

local namecallLama
namecallLama = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod and getnamecallmethod() or "?"

    if (method == "FireServer" or method == "InvokeServer")
       and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
            or self:IsA("UnreliableRemoteEvent")) then
        local ok, full = pcall(function() return self:GetFullName() end)
        local nama = ok and full or self.Name

        local args = { ... }
        local potongan = {}
        for i = 1, select("#", ...) do
            potongan[#potongan + 1] = formatArg(args[i])
        end

        catat(string.format("[SPY] %s:%s(%s)", nama, method, table.concat(potongan, ", ")))
    end

    return namecallLama(self, ...)
end)

print("[SPY] Aktif. Sekarang cabut SATU tanaman secara manual di dalam game.")
if tulisLog then
    print("[SPY] Hasil juga disalin ke shovel_log.txt")
end

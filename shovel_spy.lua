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

    Kalau executor bilang "script gagal dieksekusi" TANPA pesan error yang
    jelas: seluruh isi skrip ini sekarang dibungkus SATU pcall besar di
    bagian bawah, jadi kalau ada yang gagal DI DALAM skrip ini (bukan gagal
    mengambil skripnya lewat HttpGet), pesannya akan tercetak jelas lewat
    warn("[SPY] GAGAL: ...") -- bukan cuma pesan generik dari executor.
]]

print(string.format(
    "[SPY] Cek kemampuan executor -- hookmetamethod=%s getnamecallmethod=%s writefile=%s readfile=%s",
    typeof(hookmetamethod), typeof(getnamecallmethod), typeof(writefile), typeof(readfile)))

local ok, err = pcall(function()
    if typeof(hookmetamethod) ~= "function" then
        error("Executor ini tidak punya hookmetamethod -- spy tidak bisa jalan di sini.")
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
            local okInst, full = pcall(function() return a:GetFullName() end)
            return "Instance<" .. (okInst and full or a.ClassName) .. ">"
        elseif t == "string" then
            return string.format("%q", a)
        elseif t == "table" then
            return "table"
        else
            return tostring(a)
        end
    end

    -- Kelas Remote yang dicek dibungkus pcall satu-satu: kalau salah satu
    -- nama kelas (mis. UnreliableRemoteEvent) tidak dikenali versi
    -- engine/executor tertentu dan :IsA() melempar error untuk itu, satu
    -- kelas yang bermasalah tidak boleh menjatuhkan seluruh hook.
    local function cocokRemote(inst)
        for _, kelas in ipairs({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }) do
            local okIsA, hasil = pcall(function() return inst:IsA(kelas) end)
            if okIsA and hasil then return true end
        end
        return false
    end

    local namecallLama
    namecallLama = hookmetamethod(game, "__namecall", function(self, ...)
        local metodeOk, method = pcall(function()
            return getnamecallmethod and getnamecallmethod() or "?"
        end)
        method = metodeOk and method or "?"

        if method == "FireServer" or method == "InvokeServer" then
            local okTipe, adalahRemote = pcall(cocokRemote, self)
            if okTipe and adalahRemote then
                local okFull, full = pcall(function() return self:GetFullName() end)
                local nama = okFull and full or tostring(self)

                local args = { ... }
                local potongan = {}
                for i = 1, select("#", ...) do
                    potongan[#potongan + 1] = formatArg(args[i])
                end

                catat(string.format("[SPY] %s:%s(%s)", nama, method, table.concat(potongan, ", ")))
            end
        end

        return namecallLama(self, ...)
    end)

    print("[SPY] Aktif. Sekarang cabut SATU tanaman secara manual di dalam game.")
    if tulisLog then
        print("[SPY] Hasil juga disalin ke shovel_log.txt")
    end
end)

if not ok then
    warn("[SPY] GAGAL: " .. tostring(err))
end

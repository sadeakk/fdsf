--[[
    ACTIVITY MONITOR -- alat pemantau, BUKAN buat akk.lua/farming, khusus
    untuk melihat apa yang SUNGGUH dilakukan skrip pihak ketiga (mis. MUI Hub)
    lewat jaringan/file/clipboard saat dijalankan.

    CARA PAKAI:
      1. Jalankan skrip ini SENDIRIAN dulu, PALING AWAL, sebelum skrip pihak
         ketiga mana pun.
      2. BARU SETELAH ITU jalankan skrip yang mau dipantau (mis. loadstring
         MUI Hub-nya).
      3. Semua baris [MON] yang muncul di console (dan shovel_log gaya
         activity_monitor_log.txt kalau writefile tersedia) menunjukkan
         remote yang ditembak, request HTTP yang dikirim (ke domain mana),
         file yang ditulis, dan clipboard yang diubah -- SELAMA skrip
         pemantau ini aktif.
      4. SANGAT disarankan pakai akun cadangan/buangan, BUKAN akun farming
         utama, saat menguji skrip pihak ketiga yang belum diverifikasi.

    Ini TIDAK bisa membaca isi bytecode VM yang terobfuskasi (lihat diskusi
    soal MUI Hub) -- tapi apa pun yang skrip itu SUNGGUH lakukan lewat
    remote/HTTP/file/clipboard akan tetap tertangkap di sini, terlepas dari
    seberapa terobfuskasi kode di baliknya, karena yang dipantau adalah
    AKIBATNYA, bukan kodenya.

    KETERBATASAN JUJUR:
      - Kalau skrip yang dipantau memakai fungsi request HTTP yang TIDAK ada
        di daftar di bawah (nama globalnya beda-beda tiap executor), request
        itu tidak akan tertangkap. Daftar di bawah sudah mencakup nama-nama
        paling umum (request/http_request/syn.request/HttpService).
      - Kalau eksekusinya sendiri gagal dihook (executor tidak mendukung
        hookfunction/hookmetamethod), bagian itu dilewati dengan pesan jelas,
        bukan gagal diam-diam.
]]

print(string.format(
    "[MON] Cek kemampuan executor -- hookmetamethod=%s hookfunction=%s writefile=%s setclipboard=%s",
    typeof(hookmetamethod), typeof(hookfunction), typeof(writefile), typeof(setclipboard)))

local ok, err = pcall(function()
    local mulai = tick()
    local tulisLog = typeof(writefile) == "function"
    if tulisLog then
        pcall(function() writefile("activity_monitor_log.txt", "") end)
    end

    local function catat(pesan)
        local baris = string.format("[+%.2fs] %s", tick() - mulai, pesan)
        print(baris)
        if tulisLog then
            pcall(function()
                local lama = ""
                pcall(function() lama = readfile("activity_monitor_log.txt") end)
                writefile("activity_monitor_log.txt", lama .. baris .. "\n")
            end)
        end
    end

    local function potong(s, maks)
        s = tostring(s)
        if #s > maks then return s:sub(1, maks) .. "...(" .. #s .. " char)" end
        return s
    end

    local function formatArg(a)
        local t = typeof(a)
        if t == "Instance" then
            local okInst, full = pcall(function() return a:GetFullName() end)
            return "Instance<" .. (okInst and full or a.ClassName) .. ">"
        elseif t == "string" then
            return string.format("%q", potong(a, 300))
        elseif t == "table" then
            -- Tabel request HTTP (mis. {Url=..., Method=..., Body=...}) --
            -- field paling penting diambil manual, bukan cuma "table".
            local okUrl, url = pcall(function() return a.Url or a.url end)
            local okMethod, method = pcall(function() return a.Method or a.method end)
            if (okUrl and url) or (okMethod and method) then
                return string.format("{Url=%s, Method=%s}",
                    tostring(okUrl and url or "?"), tostring(okMethod and method or "?"))
            end
            return "table"
        else
            return tostring(a)
        end
    end

    -- ======================================================
    -- 1. REMOTE (FireServer/InvokeServer) + HttpService (PostAsync/dst)
    --    -- keduanya lewat __namecall, jadi satu hook cukup untuk dua-duanya.
    -- ======================================================
    if typeof(hookmetamethod) == "function" then
        local function cocokKelas(inst, daftarKelas)
            for _, kelas in ipairs(daftarKelas) do
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

            local args = { ... }
            local n = select("#", ...)

            if method == "FireServer" or method == "InvokeServer" then
                local okTipe, remote = pcall(cocokKelas, self,
                    { "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" })
                if okTipe and remote then
                    local okFull, full = pcall(function() return self:GetFullName() end)
                    local potongan = {}
                    for i = 1, n do potongan[#potongan + 1] = formatArg(args[i]) end
                    catat(string.format("[REMOTE] %s:%s(%s)",
                        okFull and full or tostring(self), method, table.concat(potongan, ", ")))
                end
            elseif method == "PostAsync" or method == "RequestAsync"
                or method == "GetAsync" or method == "GetAsyncFull" then
                local okTipe, http = pcall(cocokKelas, self, { "HttpService" })
                if okTipe and http then
                    local potongan = {}
                    for i = 1, n do potongan[#potongan + 1] = formatArg(args[i]) end
                    catat(string.format("[HTTP] HttpService:%s(%s)", method, table.concat(potongan, ", ")))
                end
            end

            return namecallLama(self, ...)
        end)
        print("[MON] Hook remote/HttpService aktif.")
    else
        warn("[MON] hookmetamethod tidak ada -- remote/HttpService TIDAK bisa dipantau di executor ini.")
    end

    -- ======================================================
    -- 2. Fungsi request HTTP mentah (bypass HttpService, umum dipakai
    --    skrip exploit untuk keluar ke domain non-Roblox)
    -- ======================================================
    local kandidatRequest = {
        { nama = "request",      ambil = function() return (getgenv and getgenv().request) or request end },
        { nama = "http_request", ambil = function() return (getgenv and getgenv().http_request) or http_request end },
        { nama = "syn.request",  ambil = function() return syn and syn.request end },
    }

    for _, kand in ipairs(kandidatRequest) do
        local okAmbil, fnAsli = pcall(kand.ambil)
        if okAmbil and typeof(fnAsli) == "function" then
            if typeof(hookfunction) == "function" then
                local wrapped
                wrapped = hookfunction(fnAsli, function(opts)
                    catat(string.format("[HTTP] %s(%s)", kand.nama, formatArg(opts)))
                    return wrapped(opts)
                end)
                print("[MON] Hook " .. kand.nama .. " aktif (hookfunction).")
            else
                -- Fallback tanpa hookfunction: timpa langsung nama globalnya.
                -- Cuma menangkap pemanggilan yang mencari fungsi ini LEWAT
                -- NAMA GLOBAL setelah baris ini jalan -- kalau skrip lain
                -- sudah menyimpan referensi lokal ke fungsi asli SEBELUM
                -- monitor ini aktif, panggilan lewat referensi itu tidak
                -- akan tertangkap. Jalankan monitor SEBELUM skrip lain untuk
                -- menghindari ini.
                local pembungkus = function(opts)
                    catat(string.format("[HTTP] %s(%s)", kand.nama, formatArg(opts)))
                    return fnAsli(opts)
                end

                if kand.nama == "syn.request" then
                    -- KHUSUS syn.request: timpa FIELD .request di tabel syn,
                    -- BUKAN tabel syn itu sendiri -- menimpa tabel syn utuh
                    -- akan merusak semua fungsi syn.* lain yang tidak
                    -- berhubungan dengan request sama sekali.
                    if syn then syn.request = pembungkus end
                else
                    local target = getgenv and getgenv() or _G
                    target[kand.nama] = pembungkus
                end
                print("[MON] Hook " .. kand.nama .. " aktif (fallback timpa global, TANPA hookfunction).")
            end
        end
    end

    -- ======================================================
    -- 3. Tulis file (writefile/appendfile) -- deteksi kalau ada yang coba
    --    menyimpan sesuatu ke disk (mis. data yang mau dikirim belakangan).
    -- ======================================================
    for _, nama in ipairs({ "writefile", "appendfile" }) do
        local fnAsli = (getgenv and getgenv()[nama]) or _G[nama]
        if typeof(fnAsli) == "function" then
            if typeof(hookfunction) == "function" then
                local wrapped
                wrapped = hookfunction(fnAsli, function(path, isi)
                    -- writefile PADA DIRINYA SENDIRI dipakai catat() di atas untuk
                    -- activity_monitor_log.txt -- itu DISENGAJA tidak dicatat ulang
                    -- di sini supaya tidak jadi log yang memanggil dirinya sendiri.
                    if path ~= "activity_monitor_log.txt" and path ~= "shovel_log.txt" then
                        catat(string.format("[FILE] %s(%q, %s)", nama, tostring(path), potong(isi, 200)))
                    end
                    return wrapped(path, isi)
                end)
            end
        end
    end
    print("[MON] Hook file writefile/appendfile aktif (kalau tersedia & hookfunction ada).")

    -- ======================================================
    -- 4. Clipboard -- kanal umum buat "mengambil lalu menaruh" data seperti
    --    cookie, sering dipakai bareng auto-paste ke web luar.
    -- ======================================================
    local fnClip = (getgenv and getgenv().setclipboard) or setclipboard
    if typeof(fnClip) == "function" and typeof(hookfunction) == "function" then
        local wrapped
        wrapped = hookfunction(fnClip, function(isi)
            catat(string.format("[CLIPBOARD] setclipboard(%s)", potong(isi, 200)))
            return wrapped(isi)
        end)
        print("[MON] Hook setclipboard aktif.")
    end

    print("[MON] Semua hook terpasang. SEKARANG jalankan skrip pihak ketiga yang mau dipantau.")
    if tulisLog then
        print("[MON] Hasil juga disalin ke activity_monitor_log.txt")
    end
end)

if not ok then
    warn("[MON] GAGAL: " .. tostring(err))
end

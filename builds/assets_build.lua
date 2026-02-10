local function write_bytes(assets_stream, file_stream)
    local size = 0
    while true do
        local chunk = file_stream:read(1024)
        if not chunk then break end
        size = size + #chunk
        for i = 1, #chunk do
            local byte = string.byte(chunk, i)
            assets_stream:write(string.format("%d,", byte))
        end
    end
    return size
end

local function embed_assets()

    local start = [[
typedef struct app_embedded_asset {
    const char *path;
    unsigned char *content;
    unsigned long  size;
} app_embedded_asset;

app_embedded_asset embedded_assets[] = {
    ]]

    local assets_stream = io.open("assets.h", "w")
    assets_stream:write(start)
    local assets_files = darwin.dtw.list_files_recursively("assets")

    for i=1, #assets_files do

        assets_stream:write("{\n.path = \"" .. assets_files[i] .. "\",\n .content = (unsigned char[]){")

        local file_stream = io.open("assets/"..assets_files[i], "rb")
        if not file_stream then
            error("Failed to open file: " .. assets_files[i])
        end
        local size = write_bytes(assets_stream, file_stream)
        file_stream:close()
        assets_stream:write("},\n .size = " .. size .. "\n},\n")

    end

    assets_stream:write("};\n")
    assets_stream:close()
end

darwin.add_recipe({
    name = "assets",
    description = "Embed assets into assets.h",
    outs = {"assets.h"},
    inputs = {"assets", "builds"},
    callback = function()
        print("\tStarting assets embedding")
        embed_assets()
        print("\tAssets embedding completed")
    end
})

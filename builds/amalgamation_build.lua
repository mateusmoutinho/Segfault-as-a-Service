local function write_bytes(assets_stream, file_stream)
    while true do
        local chunk = file_stream:read(1024)
        if not chunk then break end
        for i = 1, #chunk do
            local byte = string.byte(chunk, i)
            assets_stream:write(string.format("%d,", byte))
        end
    end
end
function embed_assets()
   
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
        
        assets_stream:write("{\n.path = \"" .. assets_files[i] .. "\",\n .content = {")
         
        local file_stream = io.open("assets/"..assets_files[i], "rb")
        write_bytes(assets_stream, file_stream)
        assets_stream:write("},\n .size = " .. file_stream:seek("end") .. "\n},\n")
        file_stream:close()
        
    end

    assets_stream:write("};\n")
    assets_stream:close()
end

function amalgamation_build()
    print("\tStarting amalgamation build")
    embed_assets()
    -- Generate amalgamation from main.c
    local runtime = darwin.camalgamator.generate_amalgamation("main.c")
    runtime = "#define DEFINE_DEPENDENCIES\n" .. runtime

    -- Write to release directory
    darwin.dtw.write_file("release/" .. PROJECT_NAME .. ".c", runtime)

    print("\tAmalgamation build completed")
end

darwin.add_recipe({
    name = "amalgamation",
    description = "Make a single file amalgamation of the project",
    outs = {"release/" .. PROJECT_NAME .. ".c"},
    inputs = {"main.c", "app.c", "dependencies","builds"},
    callback = amalgamation_build
})
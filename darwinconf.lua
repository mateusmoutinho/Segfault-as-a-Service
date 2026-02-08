function amalgamation_build()
    print("\tStarting amalgamation build")

    -- Generate amalgamation from main.c
    local runtime = darwin.camalgamator.generate_amalgamation("src/main.c")
    runtime = "#define DEFINE_DEPENDENCIES\n" .. runtime

    -- Write to release directory
    darwin.dtw.write_file("release/" .. PROJECT_NAME .. ".c", runtime)

    print("\tAmalgamation build completed")
end

darwin.add_recipe({
    name = "amalgamation",
    description = "Make a single file amalgamation of the project",
    outs = {"release/" .. PROJECT_NAME .. ".c"},
    inputs = {"src", "dependencies", "builds"},
    requires = {"silver_chain_organize"},
    callback = amalgamation_build
})


function debian_static_build()
    local control = [[
Package: PROJECT_NAME
Version: VERSION
Section: base
Priority: optional
Architecture: amd64
Depends: libc6 (>= 2.27)
Maintainer: FULLNAME EMAIL
Description: SUMARY
]]

    control = string.gsub(control, "PROJECT_NAME", PROJECT_NAME)
    control = string.gsub(control, "VERSION", VERSION)
    control = string.gsub(control, "SUMARY", SUMARY)
    control = string.gsub(control, "FULLNAME", FULLNAME)
    control = string.gsub(control, "EMAIL", EMAIL)

    darwin.dtw.write_file(".cache/debian_static_build/project/DEBIAN/control", control)

    darwin.dtw.copy_any_overwriting(
        "release/" .. PROJECT_NAME .. "static_linux.out",
        ".cache/debian_static_build/project/usr/local/bin/" .. PROJECT_NAME
    )

    local POST_INSTALL = [[
#!/bin/sh
set -e
chmod 755 /usr/local/bin/PROJECT_NAME
exit 0
]]

    POST_INSTALL = string.gsub(POST_INSTALL, "PROJECT_NAME", PROJECT_NAME)
    darwin.dtw.write_file(".cache/debian_static_build/project/DEBIAN/postinst", POST_INSTALL)

    local image = darwin.ship.create_machine("debian:latest")
    image.provider = CONTANIZER

    image.start({
        flags = {"-it"},
        volumes = {
            {"./.cache/debian_static_build/project", "/project"},
            {"./release", "/release"},
        },
        command = "chmod 755 /project/DEBIAN/postinst && dpkg-deb --build /project /release/" .. PROJECT_NAME .. ".deb"
    })

    print("\tDebian package build completed")
end

darwin.add_recipe({
    name = "debian",
    requires = {"static_linux","silver_chain_organize"},
    description = "Create a debian package from the static linux binary",
    outs = {"release/" .. PROJECT_NAME .. ".deb"},
    inputs = {"src", "dependencies", "builds"},
    callback = debian_static_build
})


function create_objects_ar_libs()
    local compiler = "gcc"
    if LAUNGUAGE == "cpp" then
        compiler = "g++"
    end
    os.execute("mkdir -p libs")
    local itens = {

        {command=compiler.." -c dependencies/CArgvParse.c -o libs/CArgvParse.o",out_path="libs/CArgvParse.o"},
        {command=compiler.." -c dependencies/CTextEngine.c -o libs/CTextEngine.o",out_path="libs/CTextEngine.o"},
        {command=compiler.." -c dependencies/UniversalGarbage.c -o libs/UniversalGarbage.o",out_path="libs/UniversalGarbage.o"},
        {command=compiler.." -c dependencies/cJSON.c -o libs/cJSON.o",out_path="libs/cJSON.o"},
        {command=compiler.." -c dependencies/UniversalSocket.c  -o libs/UniversalSocket.o",out_path="libs/UniversalSocket.o"},
        {command=compiler.." -c dependencies/LuaCEmbed.c  -DLUA_CEMBED_MOCK_UNIVERSAL_GARBAGE_DEFINE -o libs/LuaCEmbed.o",out_path="libs/LuaCEmbed.o"},
        {command=compiler.." -c dependencies/CWebStudio.c  -DCWEB_MOCK_CJSON_DEFINE -DCWEB_MOCK_UNIVERSAL_GARBAGE_DEFINE -DCWEB_MOCK_UNIVERSAL_SOCKET_DEFINE  -DCWEB_MOCK_CTEXT_ENGINE_DEFINE -o libs/CWebStudio.o",out_path="libs/CWebStudio.o"},
        {command=compiler..[[ -c dependencies/doTheWorldOne.c -DDTW_MOCK_CJSON_DEFINE    -o libs/doTheWorld.o]],out_path="libs/doTheWorld.o"},

    }

    for _, item in ipairs(itens) do
            os.execute(item.command)
    end

end 

function local_linux_libs_build()
    create_objects_ar_libs()
    
    print("\tLocal Linux libraries (.o objects) build completed")
end

darwin.add_recipe({
    inputs={
        "dependencies",
        "builds"
    },
    outs= {
        "libs/CArgvParse.o",
        "libs/CTextEngine.o", 
        "libs/UniversalGarbage.o",
        "libs/cJSON.o",
        "libs/UniversalSocket.o",
        "libs/LuaCEmbed.o",
        "libs/CWebStudio.o",
        "libs/doTheWorld.o"
    },
    name="local_objects_libs",
    requires={},
    description = "Build static object files (.o) for local Linux development",
    callback = local_linux_libs_build
})


function local_linux_bin_build()
    
    local build_props = {
        cflags = CFLAGS or ""
    }

    local compiler = "gcc"
    if LAUNGUAGE == "cpp" then
        compiler = "g++"
    end
   
    local compilation = compiler.." "..build_props.cflags.." -o Quill src/main.c  libs/doTheWorld.o libs/CWebStudio.o libs/cJSON.o libs/UniversalGarbage.o libs/UniversalSocket.o libs/CTextEngine.o libs/CArgvParse.o  libs/LuaCEmbed.o -ldl"

    print("compilation: ", compilation)
    os.execute(compilation)

    print("\tLocal Linux binary build completed")
end

darwin.add_recipe({
    inputs={
        "dependencies",
        "src",
        "builds",
        "libs"
    },
    outs= {
        "Quill"
    },
    name="local_unix_bin",
    requires={"local_objects_libs","silver_chain_organize"},
    description = "Build static object files and link them into a local Linux binary",
    callback = local_linux_bin_build
})

function rpm_static_build()
    darwin.dtw.copy_any_overwriting(
        "release/" .. PROJECT_NAME .. "static_linux.out",
        ".cache/rpm_static_build/SOURCES/" .. PROJECT_NAME .. "static_linux.out"
    )

    local formatted_rpm = [[
Name:           PROJECT_NAME
Version:        VERSION
Release:        1%{?dist}
Summary:        SUMARY
Source0:        PROJECT_NAME_static_linux.out

License:        LICENSE
URL:           PROJECT_URL

BuildRoot:      %{_tmppath}/%{name}-%{version}-buildroot
BuildArch:      x86_64

%description

DESCRIPITION

%prep

%build


%install
mkdir -p %{buildroot}/usr/local/bin
cp %{_sourcedir}/PROJECT_NAME_static_linux.out   %{buildroot}/usr/local/bin/PROJECT_NAME
chmod +x %{buildroot}/usr/local/bin/PROJECT_NAME
%files
/usr/local/bin/PROJECT_NAME

%changelog
* TIMEZONE - FULLNAME EMAIL  - 1.0.0-1
- YOUR_CHANGES
]]

    formatted_rpm = string.gsub(formatted_rpm, "PROJECT_NAME", PROJECT_NAME)
    formatted_rpm = string.gsub(formatted_rpm, "VERSION", VERSION)
    formatted_rpm = string.gsub(formatted_rpm, "SUMARY", SUMARY)
    formatted_rpm = string.gsub(formatted_rpm, "LICENSE", LICENSE)
    formatted_rpm = string.gsub(formatted_rpm, "DESCRIPITION", DESCRIPITION)
    formatted_rpm = string.gsub(formatted_rpm, "PROJECT_URL", URL)
    formatted_rpm = string.gsub(formatted_rpm, "FULLNAME", FULLNAME)
    formatted_rpm = string.gsub(formatted_rpm, "TIMEZONE", os.date("%a %b %d %Y"))
    formatted_rpm = string.gsub(formatted_rpm, "EMAIL", EMAIL)

    darwin.dtw.write_file(".cache/rpm_static_build/SPECS/project.spec", formatted_rpm)
    os.execute("mkdir -p .cache/rpm_static_build/RPMS")

    local image = darwin.ship.create_machine("almalinux:latest")
    image.provider = CONTANIZER
    image.add_comptime_command("dnf install rpm-build rpmdevtools -y")
    image.add_comptime_command("dnf install gcc -y")
    image.add_comptime_command("rpmdev-setuptree")

    image.start({
        flags = {"-it"},
        volumes = {
            {"./.cache/rpm_static_build/SOURCES", "/root/rpmbuild/SOURCES"},
            {"./.cache/rpm_static_build/SPECS", "/root/rpmbuild/SPECS"},
            {"./.cache/rpm_static_build/RPMS", "/root/rpmbuild/RPMS"}
        },
        command = "rpmbuild -ba ~/rpmbuild/SPECS/project.spec"
    })

    local rpms = darwin.dtw.list_files_recursively(".cache/rpm_static_build/RPMS", true)
    for _, file in ipairs(rpms) do
        if darwin.dtw.ends_with(file, ".rpm") then
            -- it will have only one rpm
            darwin.dtw.copy_any_overwriting(file, "release/" .. PROJECT_NAME .. ".rpm")
            break
        end
    end

    print("\tRPM package build completed")
end

darwin.add_recipe({
    name = "rpm",
    requires = {"static_linux"},
    description = "Create an RPM package from the static linux binary",
    outs = {"release/" .. PROJECT_NAME .. ".rpm"},
    inputs = {"src", "dependencies", "builds"},
    callback = rpm_static_build
})

function silver_chain_organize()
    local content = darwin.mdeclare.transform_dir({
        dir="src",
        startswith="fdefine",
        endswith=".c",
    })

    darwin.dtw.write_file("src/fdeclare.all.h", content)
    darwin.silverchain.remove("src/fdeclare.all.h")

    darwin.silverchain.generate({
        src = "src",
        project_short_cut = "Quill",
        implement_main = false,

        tags = { 
            "dep_declare",
            "macros",
            "types",
            "consts",
            "fdeclare",
            'globals',
            "fdefine",
            "dep_define"
            
    }})
end 

darwin.add_recipe({
    inputs={
        "src",
        "dependencies",
        "builds"
    },
    outs= {
        "src/fdeclare.all.h"
    },
    name="silver_chain_organize",
    description = "Organize source files using SilverChain",
    callback = silver_chain_organize
})

function linux_bin()
    os.execute("mkdir -p release")

    local image = darwin.ship.create_machine("alpine:latest")
    image.provider = CONTANIZER
    image.add_comptime_command("apk update")
    image.add_comptime_command("apk add --no-cache gcc g++ musl-dev curl")

    local compiler = "gcc"
    if LAUNGUAGE == "cpp" then
        compiler = "g++"
    end

    
    image.start({
        volumes = {
            {"./release", "/release"},
        },
        command = compiler .. [[ --static /release/]] .. PROJECT_NAME .. [[.c -o /release/]] .. PROJECT_NAME .. [[_linux_bin.out]]
    })

    print("\tLinux binary build completed")
end

darwin.add_recipe({
    name = "static_linux",
    requires = {"amalgamation"},
    description = "Make a static compiled linux binary of the project",
    outs = {"release/" .. PROJECT_NAME .. "_linux_bin.out"},
    inputs = {"src", "dependencies", "builds"},
    callback = linux_bin
})


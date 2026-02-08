PROJECT_NAME = "Capsule"
CONTANIZER   = darwin.argv.get_flag_arg_by_index({ "provider", "contanizer" }, 1, "podman")
PORT  = darwin.argv.get_flag_arg_by_index({ "port" }, 1, "5000")
VERSION      = "0.1.0"
LICENSE      = "Unlicense"
URL          = "https://github.com/mateusmoutinho/Capsule"
DESCRIPITION = "Capsule - C-Based Web Server Template for vibecoding"
FULLNAME     = "Mateus Moutinho"
EMAIL        = "[EMAIL_ADDRESS]"
SUMARY       = "Capsule - C-Based Web Server Template for vibecoding"
LANGUAGE     = "c"
COMPILER = darwin.argv.get_flag_arg_by_index({ "compiler" }, 1)
if not COMPILER and LANGUAGE == "cpp" then
    COMPILER = "g++"
end
if not COMPILER and LANGUAGE == "c" then
    COMPILER = "gcc"
end


-- Load all build recipes from builds/ directory
darwin.load_all("builds")
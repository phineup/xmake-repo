package("ratelimitd")
    set_homepage("https://github.com/phineup/ratelimitd")
    set_description("C++17 client SDK for the ratelimitd rate limiting sidecar (compiled or header-only).")
    set_license("MIT")

    -- ratelimitd has no release tag yet, so versions are pinned to a commit archive (SHA256 below).
    -- Once v0.1.0 is tagged, replace the table + version function with:
    --   add_urls("https://github.com/phineup/ratelimitd/archive/refs/tags/v$(version).tar.gz",
    --            "https://github.com/phineup/ratelimitd.git")
    -- and keep the same add_versions line with the tag tarball's SHA256.
    local commits = {
        ["0.1.0"] = "06865143e97460e50ea16a0b42a1b6398580857f"
    }
    add_urls("https://github.com/phineup/ratelimitd/archive/$(version).tar.gz", {
        version = function (version) return commits[tostring(version)] end
    })
    add_versions("0.1.0", "ddbc1451737de6689b04492a12abdbc551732358ff6ae8debf9b07bd90d13650")

    -- `shared`, `debug`, `pic`, `lto` and `vs_runtime` are the standard xmake configs.
    add_configs("headeronly", {description = "Use the header-only flavour (no library is built; libcurl is still linked).", default = false, type = "boolean"})

    -- Consumers must compile with C++17 (set_languages("c++17")).
    -- libcurl is the default HTTP transport in both flavours.
    add_deps("libcurl")

    on_load(function (package)
        if package:config("headeronly") then
            package:set("kind", "library", {headeronly = true})
            -- Switches <ratelimitd/ratelimitd.hpp> to include the implementation.
            package:add("defines", "RATELIMITD_HEADER_ONLY")
        end
    end)

    on_install("windows", "linux", "macosx", "bsd", "mingw", "msys", "android", "iphoneos", "cross", function (package)
        local includedir = path.join("sdk", "cpp", "include")

        if package:config("headeronly") then
            os.cp(path.join(includedir, "ratelimitd"), package:installdir("include"))
            return
        end

        -- Build with xmake itself (not the upstream CMake) so toolchains, cross
        -- compilation, runtimes and the libcurl dependency all come from xmake.
        io.writefile("xmake.lua", [[
            add_rules("mode.release", "mode.debug")
            set_languages("c++17")
            add_requires("libcurl")
            target("ratelimitd")
                set_kind("$(kind)")
                add_files("sdk/cpp/src/*.cpp")
                add_includedirs("sdk/cpp/include")
                add_headerfiles("sdk/cpp/include/(ratelimitd/**.hpp)", "sdk/cpp/include/(ratelimitd/**.ipp)")
                add_packages("libcurl")
                if is_plat("windows") and is_kind("shared") then
                    add_rules("utils.symbols.export_all", {export_classes = true})
                end
        ]])
        import("package.tools.xmake").install(package, {})
    end)

    on_test(function (package)
        -- Compile and link against the library (or the headers) ...
        assert(package:check_cxxsnippets({test = [[
            #include <ratelimitd/ratelimitd.hpp>
            void test() {
                ratelimitd::Client client("http://127.0.0.1:8080");
                auto req = ratelimitd::CheckRequest::for_policy("user", "login");
                auto transport = ratelimitd::make_curl_transport();
                (void)client; (void)req; (void)transport;
            }
        ]]}, {configs = {languages = "c++17"}}))

        -- ... and, when the host can run the result, exercise the JSON codec
        -- through a fake transport (no network involved).
        if not package:is_cross() then
            assert(package:check_cxxsnippets({test = [[
                #include <ratelimitd/ratelimitd.hpp>
                #include <memory>
                struct Fake : ratelimitd::Transport {
                    ratelimitd::HttpResponse send(const std::string&, const std::string&,
                            const std::vector<std::pair<std::string, std::string>>&,
                            const std::string&, std::chrono::milliseconds) override {
                        return {429, R"({"allowed":false,"retry_after_ms":1500,"limited_by":"r","rules":[]})"};
                    }
                };
                int main() {
                    ratelimitd::ClientOptions opt;
                    opt.transport = std::make_shared<Fake>();
                    ratelimitd::Client client("http://x", opt);
                    auto res = client.check(ratelimitd::CheckRequest::for_policy("u", "p"));
                    return (!res.allowed && res.retry_after_ms == 1500 && res.limited_by == "r") ? 0 : 1;
                }
            ]]}, {configs = {languages = "c++17"}, tryrun = true}))
        end
    end)

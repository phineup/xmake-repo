package("ratelimitd")
    set_homepage("https://github.com/phineup/ratelimitd")
    set_description("C++17 client SDK for the ratelimitd rate limiting sidecar (compiled or header-only).")
    set_license("MIT")

    add_urls("https://github.com/phineup/ratelimitd/archive/refs/tags/v$(version).tar.gz",
             "https://github.com/phineup/ratelimitd.git")
    add_versions("1.1.0", "a931ab7a5764991d3bcd6fe646dbd1a1d8b6b219d342659c52d8cfec161cba74")

    add_configs("headeronly", {description = "Use the header-only flavour (no library is built; libcurl is still linked).", default = false, type = "boolean"})

    -- libcurl is the default HTTP transport in both flavours.
    add_deps("libcurl")

    on_load(function (package)
        if package:config("headeronly") then
            package:set("kind", "library", {headeronly = true})
            -- Makes <ratelimitd/ratelimitd.hpp> include the implementation.
            package:add("defines", "RATELIMITD_HEADER_ONLY")
        end
    end)

    on_install(function (package)
        local includedir = path.join("sdk", "cpp", "include")

        if package:config("headeronly") then
            os.cp(path.join(includedir, "ratelimitd"), package:installdir("include"))
            return
        end

        -- The upstream root xmake.lua also drives the tests and the Rust SDK, so use a
        -- minimal one: toolchains, cross compilation and libcurl then all come from xmake.
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
        import("package.tools.xmake").install(package)
    end)

    on_test(function (package)
        -- Compiles and links against the library (or the headers) ...
        assert(package:check_cxxsnippets({test = [[
            #include <ratelimitd/ratelimitd.hpp>
            void test() {
                ratelimitd::Client client("http://127.0.0.1:8080");
                auto req = ratelimitd::CheckRequest::for_policy("user", "login");
                auto transport = ratelimitd::make_curl_transport();
                (void)client; (void)req; (void)transport;
            }
        ]]}, {configs = {languages = "c++17"}}))

        -- ... and, when the host can run the result, exercises the JSON codec through a
        -- fake transport (no network involved).
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

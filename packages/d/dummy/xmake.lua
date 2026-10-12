package("dummy")
    set_homepage("https://github.com/phineup/phineup-xmake-repo")
    set_kind("library", {headeronly = true})
    set_description("Placeholder package that keeps the repository testable. Replace with real packages.")
    set_license("MIT")

    -- Local source: no download, so no URL/SHA256 is needed for this placeholder.
    -- Real packages use add_urls + add_versions("<version>", "<sha256>").
    set_sourcedir(path.join(os.scriptdir(), "src"))

    on_install(function (package)
        os.cp("dummy.h", package:installdir("include"))
    end)

    on_test(function (package)
        assert(package:has_cincludes("dummy.h"))
    end)
